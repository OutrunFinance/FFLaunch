# FFLaunch

首个Fair&Free Launch标准，灵感来自于铭文。

还记得前段时间的铭文 Summer 吗？

试想一下将铭文的 FairLaunch 特性与 LaunchPad 结合会是什么样的呢？

FFLaunch 将 OutrunDao 的另外两个产品 "Outstake" 和 "Outswap" 组合起来，利用它们的优势创造了史上最公平公正的代币发行方式。

像发行铭文一样发行 ERC20 Token, 用户通过质押锁定 ETH 来 mint token, 在 mint 的过程中 质押的产生的 osETH 将会和合约中预留的部分 Token 组成交易对在 Outswap 上提供流动性。LP 将锁定一段时间，用户会获得质押锁定 ETH 而得到的 YieldToken, 锁定时间到期后用户可以取出自己的 osETH 与预留 token 组成的 LP。这相当于用户免费得获得了这些代币，同时持续参与项目的整个流动性建设过程。

对于项目团队来说，他们所募集的资金是就是 LP 锁定期间交易对产生的交易手续费。在基于上述核心基本要求的情况下，我们还为项目方提供了可定制的 callee 接口以支持 FFLaunch 的灵活性, 项目方可以在 Fair And Free 的基础上构建自己独特的 Launch 逻辑。

相比于传统的 ICO 或 IDO, FFLaunch 的模式更加公平，对投资者更加友好。投资者可以免费获得项目方的代币，同时还可以防止项目团队像传统 IDO 一样募集大量资金后就 RUG 或者不在继续用心开发产品。项目方想募集更多资金就需要在 LP 锁定期间不断迭代产品，让用户愿意交易自己的代币，从而获得持续增长的现金流。并且 FFLaunch 模式是社区共建流动性，由于代币相当于免费获得，在这种情况下会聚集更多的流动性，从而提高流动性池的深度，这对于一个刚启动的新项目来说非常重要。

## 无风险 LaunchPad

我们可以大声地喊出，我们是史上第一个 “无风险” LaunchPad，对于参与的用户来说，风险极低，可以获得类似国债一般风险极低的无风险收益，为什么可以这么说？

我们想象这样一个场景，用户在参与一个 mintFee 不会变化的 LaunchPool 时，每个用户会获得的代币的成本是一样的（因为 mintFee 没有变化），同时他们所支出的 mintFee 会与预留的一部分代币组成 LP 并锁定一段时间，在锁定到期后 LP 将会归还给用户，用户会再次获得他们支出的 mintFee 与 预留的那部分代币。

接下来是重点，在我们的审核下，在 FFLaunch 上启动的的所有项目，在 LP 锁定期间不能铸造或者释放新的代币。在锁定到期一周后才可以释放新的代币。也就是说，即使所有的用户在 FFLaunch 事件结束时同时出售了手里的所有代币，在这个没有新增代币的封闭系统中，当 LP 锁定时间到期时，他们会重新获得他们出售的代币和部分 mintFee，这还是在 LP 锁定期间没有任何人购买代币的情况下，当有新的用户购买代币时，所有的早期参与者都将被奖励。

在这种“无风险”的情况下，参与的资金将会比普通的 LaunchPad 更多，代币将会获得充足的流动性支持和市场关注度，项目团队也会获得足够的手续费收入，实现双赢，这才是真正的一级市场，而不是那些 Fake IDO，这才是 WEB3!!!

**我们更鼓励实名的初创团队在我们平台进行社区种子轮融资，锁定更长的时间，获取持续的收入流以支持项目的开发。**
**我们也鼓励具有强大社区与运营团队的meme coin在我们平台上公平发射，获取持续的收入流以支持社区的运营。**

## FFLaunch 对 Outstake 和 Outswap 的影响

由于参与 FFLanch 的 ETH 与 USDB 会被质押在 Outstake 协议中，然后再预留的 token 组成 LP 并锁定与前者质押时间相同的时间。所以参与 FFLanch 用户会同时获得 Blast 原生收益并提高 Outstake 的 TVL.

而 Outstake 铸造的 osETH 和 osUSD 则被锁定在 Outswap 之中。用户购买 token 需要使用 osETH 或 osUSD，这无疑会提高市场对 osETH 和 osUSD 的需求，用户会选择质押更多的 ETH 与 USDB，或者直接从 Outswap 上购买。因此 Outswap 的 TVL 与交易量也会得到提升。

在 LP 锁定的很长时间里，用户都使用 osETH 和 osUSD 进行交易，这对于培养用户习惯至关重要，未来越来越多的交易对，越来越多的人会使用 osETH 和 osUSD，让 Outrun 生态更加繁荣。这是很多 LST 都无法做到的事，也是对当前 LST 使用场景受限的重大破局。

## 事件生命周期

在 FFLaunch 事件的生命周期中一共有 3 个实体，6 个阶段。

实体：

1. 用户  
2. Outrun FFLauncher  
3. 第三方团队

阶段：

1. 申请阶段  
2. 审核阶段  
3. Deposit 阶段  
4. Claim 阶段  
5. 开放交易阶段  
6. LP 解锁阶段

## 申请阶段

+ 第三方团队编写 Callee 与 Token 合约，Callee 合约需要实现 IPoolCallee 接口，Token 合约需要继承 FFT 合约（可重写部分方法）。
+ 第三方团队向申请上线 Outrun FFLauncher，需要提交项目与团队详细资料以及 Callee 与 Token 合约，并持续与 OutrunDao 审核团队交流。

## 审核阶段

+ OutrunDao 审核团队将详细审核第三方团队提交的相关资料并与第三方团队交流。
+ OutrunDao 审核团队将审计第三方团队提交的 Callee 与 Token 合约，检查是否为恶意合约或者存在安全漏洞。
+ OutrunDao 审核团队将检查 Token 的释放情况，在 LP 锁定期间，不得释放新的代币。
+ 若审核未通过，OutrunDao 审核团队将会对第三方团队提出修改建议，第三方团队需要重新申请。
+ 若审核通过，OutrunDao 审核团队将会向 Outrun FFLauncher 注册新的LaunchPool.

## Deposit 阶段

+ 当区块时间在已注册的 Pool 的 startTime 与 endTime 之间时，用户可以调用 FFLauncher 合约的 deposit 方法，向该 Pool 的临时资金池存款。需要注意的是 Deposit 阶段和 Claim 阶段有部分时间是重合的。

## Claim 阶段

+ 当区块时间在已注册的 Pool 的 claimDeadline 之前时，用户可以调用 FFLauncher 合约的 claimTokenOrFund 方法，将自己在临时资金池中的存款质押到 Outstake 中以获取流动性质押代币与 YieldToken, 并调用第三方团队注册的 Callee 合约向 Outswap 添加流动性，LP将会锁定在 FFLauncher 合约中。然后用户会获得第三方团队的 Token.
+ 当区块时间在已注册的 Pool 的 claimDeadline 之后时，此时已经是开放交易阶段， 用户无法再 Claim 第三方团队的 Token，而是会执行 Refund 操作，将自己在临时资金池中的资金取出来。

## 开放交易阶段

+ Claim 阶段结束后，第三方团队打开交易开关，此时 Token 可转移，Token 可以自由交易。
+ 在这个阶段期间，锁定在 FFLauncher 合约中的 LP 所产生的做市收益会由第三方团队获得，即第三方团队募集到的资金。

## LP 结算阶段

+ 当 LP 锁定时间到期后，用户可以调用 FFLauncher 合约的 claimPoolLP 方法，将自己在 Claim 阶段锁定的 LP 提取出来。第三方团队不会再获得 LP 所产生的做市收益。
