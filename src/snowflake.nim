
# +-----------------------+--------------------+-----------------+--------------------+
# |   NextIdBits (41)     | DataCenterBits (5) | MachineBits (5) | SequenceBits (12)  |
# +-----------------------+--------------------+-----------------+--------------------+

import times, locks

const
  #Starting Unix timestamp, accurate to milliseconds
  Epoch: int64 = 1722094029797  

  DataCenterBits: int64 = 5
  MachineBits: int64 = 5
  SequenceBits: int64 = 12

  #Left shift digits for each segment
  LastTimeShl = DataCenterBits + MachineBits + SequenceBits
  DataCenterShl = MachineBits + SequenceBits
  MachineShl = SequenceBits

  MaxSequence: int64 = -1 xor (-1 shl SequenceBits)
  
  DatacenterId: int64 = 0  # max: 2 ^ DataCenterBits - 1
  MachineId: int64 = 0     # max: 2 ^ MachineBits - 1

var
  lock {.global.}: Lock 
  lastStmp, sequence {.global, guard: lock.}: int64

proc getCurrentTimeMs(): int64 = 
  int64(epochTime() * 1000)

initLock lock

proc nextId*(): int64 {.thread.} =
  withLock(lock):
    var time = getCurrentTimeMs()
    while time < lastStmp:
      time = getCurrentTimeMs()
    var sequenceTmp = 0'i64  
    if(time == lastStmp):
      sequenceTmp = (sequence + 1) and MaxSequence
      if sequenceTmp == 0:
        while time <= lastStmp:
          time = getCurrentTimeMs()
    sequence = sequenceTmp
    lastStmp = time
    result = (lastStmp - Epoch) shl LastTimeShl or 
      DatacenterId shl DataCenterShl or
      MachineId shl MachineShl or 
      sequence

#Convert nextId to UTC time (int64 milliseconds)
proc idToTimeMs*(id: int64): int64 =
  (id shr LastTimeShl) + Epoch

#Convert nextId to Datetime
proc idToDateTime*(id: int64, zone: Timezone = utc()): DateTime =  
  fromUnixfloat(((id shr LastTimeShl) + Epoch) / 1000). inZone(zone)

# example:
  
# let id = nextId()
# echo id
# echo idToTimeMs(id)
# echo idToDateTime(nextId(), local())
