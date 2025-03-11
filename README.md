## 项目内容

### 功能说明

#### - 一个质押挖矿合约，质押RNT，挖矿esRNT，esRNT可以兑换为RNT，也可以赎回。挖矿期一个月,到期可以自动重新开始质押。
#### - 挖矿期间，用户可以随时赎回，赎回时，按照时间比例赎回，未赎回的esRNT，将被销毁。
#### - 挖矿期满，用户可自行兑换奖励。
#### - 挖矿期间，用户可以随时查看挖矿信息，包括质押信息，挖矿信息，赎回信息，奖励信息。

### 主要函数

#### - testClaimReward() (gas: 237703)
#### - testEmergencyWithdraw() (gas: 36673)
#### - testEmergencyWithdrawNonOwner() (gas: 13900)
#### - testGetLockCount() (gas: 232168)
#### - testPendingRewards() (gas: 94366)
#### - testRedeemFull() (gas: 253169)
#### - testRedeemPartial() (gas: 253521)
#### - testStake() (gas: 92790)
#### - testStakeAdditional() (gas: 238756)
#### - testUnstake() (gas: 100331)
#### - testUnstakeAll() (gas: 88043)