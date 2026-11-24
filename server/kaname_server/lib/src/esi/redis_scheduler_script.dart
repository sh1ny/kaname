// Redis uses separate expiry indexes to mutate only the touched bucket and
// representation records. The global record contains only bounded admission
// state (tickets, active sends, error epoch, and status-probe state).
const schedulerScript = r'''
local action, incarnation = ARGV[1], ARGV[2]
local requestedNow, maxGroups = tonumber(ARGV[3]), tonumber(ARGV[4])
local arg = cjson.decode(ARGV[5])
if not requestedNow or not maxGroups or
   (action ~= 'admit' and action ~= 'advance' and action ~= 'complete') then
  return redis.error_reply('invalid scheduler transition')
end
local completionGrace = 5000
local metaKey, bucketKey = KEYS[2], KEYS[4]
local metaExpiry, bucketExpiry = KEYS[3], KEYS[5]
local encoded = redis.call('GET', KEYS[1])
local g = encoded and cjson.decode(encoded) or nil
if not g or g.incarnation ~= incarnation then
  redis.call('UNLINK', metaKey, metaExpiry, bucketKey, bucketExpiry)
  g = {incarnation=incarnation, now=requestedNow, recovery=requestedNow+3600000,
       serial=g and g.serial or 0, epoch=0, epochEnd=0,
       tickets={}, calls={}, lateCalls={}, gone={}, errors={}, learned={}, conflicts={}, routeBlocks={},
       errorBlocked=0, errorLast=-1000, probeAt=0, probeDelay=30000}
end
local now = math.max(requestedNow, g.now)
g.now = now
local function answer(result)
  redis.call('SET', KEYS[1], cjson.encode(g))
  return cjson.encode(result)
end
local function refused(reason, untilAt, status)
  return {kind='denied', reason=reason, untilAt=untilAt, status=status}
end
if now < g.recovery then
  -- Old-incarnation completions have no reservation to reconcile.
  if action == 'complete' then return answer({kind='complete'}) end
  return answer(refused('stateRecovering', g.recovery))
end

local function probeFailed(retry)
  g.probe = nil
  g.probeAt = now + math.max(g.probeDelay, retry or 0)
  g.probeDelay = math.min(300000, 2 * g.probeDelay)
end
local active = 0
for id, call in pairs(g.lateCalls) do
  if call.untilAt+completionGrace <= now then g.lateCalls[id] = nil end
end
for id, call in pairs(g.calls) do
  if call.untilAt <= now then
    if call.untilAt+completionGrace > now then g.lateCalls[id] = call end
    g.calls[id] = nil
  else active = active + 1 end
end
if g.probe and not g.calls[g.probe] then probeFailed() end
local queueSize = 0
for id, ticket in pairs(g.tickets) do
  if ticket.live <= now then g.tickets[id] = nil else queueSize = queueSize + 1 end
end
for id, untilAt in pairs(g.gone) do if untilAt <= now then g.gone[id] = nil end end
if g.epochEnd <= now then
  g.epochEnd = now+60000
  g.epoch = g.epoch+1
  g.errors, g.errorCeil, g.errorSequence = {}, nil, nil
end

local function expire(hash, expiry)
  local expired = redis.call('ZRANGEBYSCORE', expiry, '-inf', now, 'LIMIT', 0, 32)
  if #expired > 0 then
    redis.call('HDEL', hash, unpack(expired))
    redis.call('ZREM', expiry, unpack(expired))
  end
end
expire(metaKey, metaExpiry)
expire(bucketKey, bucketExpiry)
local metadata, budgets = {}, {}
local function load(hash, key, cache)
  local entry = cache[key]
  if entry == nil then
    local data = redis.call('HGET', hash, key)
    entry = data and cjson.decode(data) or false
    cache[key] = entry
  end
  if entry and entry.untilAt > now then return entry end
end
local function save(hash, expiry, key, value, cache)
  redis.call('HSET', hash, key, cjson.encode(value))
  redis.call('ZADD', expiry, value.untilAt, key)
  cache[key] = value
end
local function count(expiry)
  return redis.call('ZCOUNT', expiry, '(' .. now, '+inf')
end
local function limit(r)
  if r.group then return r.group, r.capacity, r.window end
  local learnt = g.learned[r.operation]
  if learnt and learnt.untilAt > now then return learnt.group, learnt.capacity, learnt.window end
end
local function groupId(name, r) return name .. ':' .. r.scope end
local function tier(remaining, capacity)
  if remaining * 100 > capacity * 50 then return 1 end
  if remaining * 100 > capacity * 25 then return 2 end
  if remaining * 100 > capacity * 10 then return 3 end
  return 4
end
local function errorsRemaining()
  local localRemain = 100-active
  local observed = (g.errorCeil or 100)-active
  for _, id in ipairs(g.errors) do
    localRemain = localRemain-1
    if id > (g.errorSequence or 0) then observed = observed-1 end
  end
  return math.min(localRemain, observed)
end
local function budgetFor(id)
  return load(bucketKey, id, budgets)
end
local function groupRemaining(b)
  if b.available then return b.available, b.nextRecovery end
  local available, observed, recover = b.capacity, b.ceiling or b.capacity, nil
  if (b.ceilingEnd or 0) <= now then observed = b.capacity end
  for id, debit in pairs(b.debits) do
    local expires = debit[1] + b.window
    if expires <= now then b.debits[id] = nil else
      available = available - debit[2]
      if (b.ceilingEnd or 0) > now and (debit[3] or tonumber(id) > b.sequence) then
        observed = observed - debit[2]
      end
      recover = math.min(recover or expires, expires)
    end
  end
  b.available, b.nextRecovery = math.min(available, observed), recover or b.ceilingEnd
  return b.available, b.nextRecovery
end
local function denial(r)
  local conflict = g.conflicts[r.operation] or 0
  if conflict > now then return refused('routeConflict', conflict) end
  local routeBlock = g.routeBlocks[r.operation] or 0
  if routeBlock > now then return refused('budget', routeBlock) end
  if r.probe then
    if not g.paused or g.probe or g.probeAt > now then return refused('outage', g.probeAt) end
  elseif r.poll and g.paused then return refused('outage', g.probeAt) end
  local newKeys = 0
  if r.negative then
    local entry = load(metaKey, 'n:' .. r.negative, metadata)
    if entry and entry.status and entry.negativeUntil > now then
      return refused('negativeCached', entry.negativeUntil, entry.status)
    end
    if not entry then newKeys = newKeys+1 end
  end
  if r.poll then
    local entry = load(metaKey, 'p:' .. r.poll, metadata)
    if r.retained and entry and (entry.freshUntil or 0) > now then return refused('notDue', entry.freshUntil) end
    if not entry then newKeys = newKeys+1 end
  end
  if newKeys > 0 and count(metaExpiry)+newKeys > 16384 then return refused('scopeCapacity') end
  if r.corp then
    for _, call in pairs(g.calls) do
      if call.r.corp == r.corp then return refused('corpBusy', call.untilAt) end
    end
  end
  if g.errorBlocked > now then return refused('stopped', g.errorBlocked) end
  if tier(errorsRemaining(), 100) == 4 then return refused('stopped', g.epochEnd) end
  local name, capacity = limit(r)
  if name then
    local b = budgetFor(groupId(name, r))
    if not b and count(bucketExpiry) >= maxGroups then return refused('scopeCapacity') end
    if b then
      if (b.block or 0) > now then return refused('budget', b.block) end
      local available, recover = groupRemaining(b)
      if available < 5 then return refused('budget', recover) end
      if tier(available, b.capacity) == 4 then return refused('stopped', recover) end
    elseif capacity < 5 then return refused('budget') end
  end
end
local function pacing(level, last, inUse)
  return level == 1 or (level == 2 and last+1000 <= now) or (level == 3 and inUse == 0)
end
local function slot(r)
  if active >= 8 or not pacing(tier(errorsRemaining(), 100), g.errorLast, active) then return false end
  local name = limit(r)
  if name then
    local key = groupId(name, r)
    local b = budgetFor(key)
    if b then
      local inUse = 0
      for _, call in pairs(g.calls) do if call.bucket == key then inUse = inUse+1 end end
      return pacing(tier(groupRemaining(b), b.capacity), b.last, inUse)
    end
  end
  return true
end
local function before(a,b)
  return a.r.priority < b.r.priority or (a.r.priority == b.r.priority and a.id < b.id)
end
local function preceded(ticket)
  for _, other in pairs(g.tickets) do
    if before(other, ticket) and not denial(other.r) and slot(other.r) then return true end
  end
  return false
end
local function makeBudget(capacity, window)
  return {capacity=capacity, window=window, last=-1000, debits={}}
end
local function persistBudget(key, b)
  b.available, b.nextRecovery = nil, nil
  b.untilAt = math.max(b.block or 0, b.ceilingEnd or 0, b.last+b.window)
  save(bucketKey, bucketExpiry, key, b, budgets)
end
local function extendLearned(r, learned, untilAt)
  learned.untilAt = math.max(learned.untilAt or 0, untilAt)
  g.learned[r.operation] = learned
end
local function grant(ticket)
  local r = ticket.r
  g.serial = g.serial+1
  local id, untilAt = g.serial, now+30000
  local completionBy = untilAt+completionGrace
  local name, capacity, window = limit(r)
  local key = name and groupId(name,r)
  if key then
    local b = budgetFor(key) or makeBudget(capacity,window)
    groupRemaining(b)
    b.last = now
    b.debits[tostring(id)] = {now,5,true}
    persistBudget(key,b)
    if not r.group then
      extendLearned(r, g.learned[r.operation], math.max(completionBy,b.untilAt))
    end
  end
  local function reserveMetadata(key)
    local entry = load(metaKey, key, metadata) or {sequence=0,untilAt=0}
    if entry.untilAt < completionBy then
      entry.untilAt = completionBy
      save(metaKey, metaExpiry, key, entry, metadata)
    end
  end
  if r.negative then reserveMetadata('n:' .. r.negative) end
  if r.poll then reserveMetadata('p:' .. r.poll) end
  local token = tostring(id)
  g.calls[token] = {r=r, epoch=g.epoch, untilAt=untilAt, bucket=key, group=name, window=window}
  g.errorLast = now
  if r.probe then g.probe = token end
  -- A 5 s dispatch window leaves 5 s to reconcile after the 20 s wire limit.
  return {kind='granted', id=id, by=now+5000}
end
if action == 'admit' then
  g.serial = g.serial+1
  local ticket = {id=g.serial,r=arg,untilAt=now+5000,live=now+1000}
  local no = denial(arg)
  if no then return answer(no) end
  if slot(arg) and not preceded(ticket) then return answer(grant(ticket)) end
  if queueSize >= 64 then
    local loser = nil
    for _, other in pairs(g.tickets) do if not loser or before(loser,other) then loser=other end end
    if not before(ticket,loser) then return answer(refused('queueFull')) end
    local removed = tostring(loser.id)
    g.tickets[removed] = nil
    g.gone[removed] = loser.untilAt
  end
  g.tickets[tostring(ticket.id)] = ticket
  return answer({kind='waiting',id=ticket.id})
elseif action == 'advance' then
  local index = tostring(arg)
  local ticket = g.tickets[index]
  if not ticket then return answer(refused(g.gone[index] and 'queueFull' or 'waitExpired')) end
  local no = denial(ticket.r)
  if no then g.tickets[index] = nil; return answer(no) end
  if slot(ticket.r) and not preceded(ticket) then
    g.tickets[index] = nil
    return answer(grant(ticket))
  end
  ticket.live = math.min(ticket.untilAt,now+1000)
  return answer({kind='waiting',id=ticket.id})
end

local id, observation = arg.id, arg.observation
local index = tostring(id)
local call = g.calls[index] or g.lateCalls[index]
if not call then return answer({kind='complete'}) end
g.calls[index],g.lateCalls[index] = nil,nil
local r, status = call.r, observation.status
local sent = call.untilAt-30000
local actual = 5
if observation.unsent then actual=0
elseif status and status >= 200 and status < 300 then actual=2
elseif status and status >= 300 and status < 400 then actual=1
elseif status and (status==429 or status>=500) then actual=0 end
local learned = not r.group and g.learned[r.operation] or nil
if learned and learned.untilAt <= now then learned = nil end
local originalGroup = call.group or (learned and learned.group)
local name = originalGroup or observation.group
if observation.group and originalGroup and observation.group ~= originalGroup then
  g.conflicts[r.operation] = math.max(g.conflicts[r.operation] or 0,
      now + math.max((learned and learned.window) or call.window or 0, observation.window))
end
if name then
  local key = groupId(name,r)
  local matched = observation.group == name
  local retainUntil = 0
  if not r.group and matched then
    learned = {
      group=name,capacity=math.min((learned and learned.capacity) or observation.capacity,observation.capacity),
      window=math.max((learned and learned.window) or 0,observation.window),
      untilAt=learned and learned.untilAt or 0,
    }
    retainUntil = now+learned.window
  end
  local capacity = (learned and learned.capacity) or (matched and observation.capacity) or r.capacity
  local window = (learned and learned.window) or (matched and observation.window) or r.window
  local b = budgetFor(key)
  local reserve = b and 0 or 1
  if not b and (matched or status == 429) and count(bucketExpiry) < maxGroups then
    b = makeBudget(capacity,window)
  end
  if b then
    groupRemaining(b)
    local cost = matched and observation.cost or actual
    if cost == 0 then b.debits[index] = nil
    else b.debits[index] = {sent,cost,false}; b.last=math.max(b.last,sent) end
    if matched then
      b.capacity = math.min(b.capacity,capacity)
      b.window = math.max(b.window,window)
      if id > (b.sequence or 0) then
        b.sequence,b.ceiling,b.ceilingEnd = id,observation.remaining,sent+b.window
      end
    end
    if status == 429 then b.block = math.max(b.block or 0,now+(observation.retry or b.window)) end
    -- At most seven peers; charge pending work against each peer's own scope.
    if matched and learned and not call.bucket then
      for token, pending in pairs(g.calls) do
        if not pending.bucket and pending.r.operation == r.operation then
          local peer = groupId(name,pending.r)
          local target = peer == key and b or budgetFor(peer)
          if not target and count(bucketExpiry)+reserve < maxGroups then
            target = makeBudget(capacity,window)
          end
          if target then
            pending.bucket, pending.group, pending.window = peer, name, window
            local peerSent = pending.untilAt-30000
            target.debits[token] = {peerSent,5,true}
            target.last = math.max(target.last,peerSent)
            if peer ~= key then
              persistBudget(peer,target)
              retainUntil = math.max(retainUntil,target.untilAt)
            end
            retainUntil = math.max(retainUntil,pending.untilAt+completionGrace)
          end
        end
      end
    end
    persistBudget(key,b)
    retainUntil = math.max(retainUntil,b.untilAt)
  end
  if learned then extendLearned(r,learned,retainUntil) end
elseif status == 429 then
  g.routeBlocks[r.operation] = math.max(g.routeBlocks[r.operation] or 0,now+(observation.retry or 60000))
end
if not observation.unsent and (not status or status < 200 or status >= 400) then
  table.insert(g.errors,id)
end
if observation.errorsRemaining and call.epoch == g.epoch and id > (g.errorSequence or 0) then
  g.errorSequence,g.errorCeil = id,observation.errorsRemaining
  g.epochEnd=math.max(g.epochEnd,now+observation.errorReset)
end
if status == 420 then
  g.errorBlocked=math.max(g.errorBlocked,now+(observation.retry or observation.errorReset or 60000))
end
local function update(key,fields,untilAt)
  local entry=load(metaKey,key,metadata)
  if entry and entry.sequence < id then
    fields.sequence,fields.untilAt = id,math.max(entry.untilAt,untilAt)
    save(metaKey,metaExpiry,key,fields,metadata)
  end
end
if r.negative then
  if status == 403 or status == 404 then
    update('n:'..r.negative,{status=status,negativeUntil=now+60000},now+60000)
  elseif status and status >= 200 and status < 400 then update('n:'..r.negative,{},call.untilAt) end
end
if r.poll then
  if observation.freshUntil then
    local expiry=observation.freshUntil
    update('p:'..r.poll,{freshUntil=expiry},math.max(expiry,call.untilAt))
  end
  local failed=observation.connectivityFailure
  if not failed and (status==502 or status==503 or status==504) then
    local previousRoute = g.failedRoute
    failed = previousRoute and previousRoute ~= r.operation and g.failedAt+30000 >= now
    g.failedRoute,g.failedAt=r.operation,now
  end
  if failed then
    if not g.paused then g.probeAt=now end
    g.paused=true
  end
end
if g.probe == index then
  g.probe=nil
  if observation.probeHealthy then
    g.paused,g.probeDelay,g.failedRoute=false,30000,nil
  else probeFailed(observation.retry) end
end
return answer({kind='complete'})
''';
