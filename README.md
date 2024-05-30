**Read this in Chinese: [中文](README.cn.md)**

# FFLaunch

The first Fair and Free Launch standard, inspired by the inscription.

Do you remember the recent inscription Summer?

Imagine combining inscription's FairLaunch feature with LaunchPad.

FFLaunch combines OutrunDao's other two products, "Outstake" and "Outswap," leveraging their strengths to create the fairest token issuance method in history.

Issuing ERC20 tokens like inscription, users can mint tokens by staking and lock ETH. During the minting process, The osETH generated from staking will be paired with a portion of tokens reserved in the contract to provide liquidity on Outswap. LP tokens will be locked for a period, and users will receive YieldTokens based on the locked staked ETH. After the lockup period, users can withdraw their osETH along with the LP tokens consisting of reserved tokens. This is equivalent to users getting these tokens for free while simultaneously participating in the entire liquidity-building process of the project.

For the project team, the funds they raise come from the trading fees collected by the trading pairs during the LP lockup period.With the core fundamental requirements mentioned above, we also provide customizable callee interfaces for project teams to support the flexibility of FFLaunch. This allows project teams to build their own unique launch logic on top of the Fair And Free foundation.

Compared to traditional ICOs or IDOs, the FFLaunch model is fairer and more investor-friendly. Investors can obtain the project's tokens for free, while also preventing the project team from conducting rug pulls or abandoning further development of the product after raising a large amount of funds, as is common in traditional IDOs. To raise further funds, project teams must continuously iterate on products during the LP lock-up period, encouraging users to trade their tokens. This facilitates sustained growth in cash flow. Furthermore, the FFLaunch model fosters community-driven liquidity. Since tokens are essentially obtained for free, this encourages more liquidity to be pooled, thereby increasing the depth of the liquidity pool. This is crucial for a newly launched project.

## Risk-Free LaunchPad

We can proudly proclaim that we are the first "risk-free" LaunchPad in history. For participating users, the risk is extremely low, and they can obtain a risk-free return similar to that of government bonds. Why can we say this?

Let's imagine a scenario where users participate in a LaunchPool with a fixed mintFee. Each user will incur the same cost for the tokens they receive since the mintFee does not change. The mintFee paid by users will be combined with a reserved portion of tokens to form an LP, which will be locked for a certain period. After the lock period expires, the LP will be returned to the users, and they will receive back the mintFee they paid along with the reserved portion of tokens.

Here’s the key point: under our supervision, all projects launched on FFLaunch cannot mint or release new tokens during the LP lock period. New tokens can only be released one week after the lock period expires. This means that even if all users simultaneously sell their tokens at the end of the FFLaunch event, in this closed system with no new tokens being added, when the LP lock period expires, they will regain their sold tokens and part of the mintFee. The scenario mentioned above only applies if no one buys tokens during the LP lock period. If new users do purchase tokens, all early participants will be rewarded.

In this "risk-free" scenario, the participation funds will exceed those of ordinary LaunchPads. The tokens will receive ample liquidity support and market attention, and the project team will earn sufficient fee income, achieving a win-win situation. This is the true primary market, not those fake IDOs. This is the true essence of Web3!!!

**We particularly encourage verified startup teams to conduct community seed rounds on our platform, locking in for longer durations to secure continuous revenue streams for supporting project development.**

## Impact of FFLaunch on Outrun Ecosystem

### Outstake

The ETH and USDB participating in FFLaunch will be staked in the Outstake protocol. These assets are then combined with reserved tokens to form LPs, which are locked for the same duration as the Outstake. As a result, users participating in FFLaunch will simultaneously receive native Blast rewards and increase Outstake's TVL.

### Outswap
The osETH and osUSD minted by Outstake will be locked in Outswap. Users need to use osETH or osUSD to purchase tokens, which will undoubtedly increase the demand for osETH and osUSD. Users will choose to stake more ETH and USDB, or directly buy from Outswap. Consequently, both the TVL and trading volume of Outswap will increase.

### Long-term Benefits
During the long LP lock period, users will use osETH and osUSD for trading. This is crucial for cultivating user habits. In the future, more trading pairs and more users will utilize osETH and osUSD, making the Outrun ecosystem more prosperous. This is something that many other Liquid Staking Tokens (LSTs) cannot achieve and represents a significant breakthrough in overcoming the current limitations of LST usage scenarios.

## Event Lifecycle

There are a total of 3 entities and 6 stages in the lifecycle of the FFLaunch event.

Entities:

1. Investor  
2. Outrun FFLauncher  
3. Third-party team

Stages:

1. Apply Stage  
2. Audit Stage  
3. Deposit Stage  
4. Claim Stage  
5. Open Trading Stage  
6. LP Settlement Stage

### Apply Stage

+ Third-party team develops Callee and Token contracts. The Callee contract must implement the IPoolCallee interface, while the Token contract should inherit from the FFT contract (with the ability to override certain methods).

+ Third-party team applies to list on Outrun FFLauncher, submitting detailed project and team information along with the Callee and Token contracts. Continuous communication with the OutrunDao audit team is required.

### Audit Stage

+ The OutrunDao audit team thoroughly reviews the submitted materials from the third-party team and engages in communication with them.

+ The OutrunDao audit team conducts an audit of the Callee and Token contracts submitted by the third-party team, checking for malicious contracts or security vulnerabilities.
If the audit fails, the OutrunDao audit team provides modification suggestions to the third-party team, which must then reapply.
If the audit passes, the OutrunDao audit team registers a new LaunchPool with Outrun FFLauncher.

### Deposit Stage

+ During the time between the registered Pool's startTime and endTime, users can call the deposit method of the FFLauncher contract to deposit funds into the temporary pool of that Pool. It's important to note that there is some overlap in time between the Deposit and Claim stages.

### Claim Stage

+ Before the claimDeadline of the registered Pool, users can call the claimTokenOrFund method of the FFLauncher contract to stake their deposits in the temporary fund pool to Outstake in order to obtain liquidity staking tokens and YieldTokens. They also invoke the Callee contract registered by the third-party team to add liquidity to Outswap. The LP will be locked in the FFLauncher contract. Subsequently, users will receive tokens from the third-party team.

+ After the claimDeadline of the registered Pool, it is the open trading stage. Users cannot claim tokens from the third-party team anymore. Instead, they will execute a refund operation to withdraw their funds from the temporary fund pool.

### Open Trading Stage

+ After the Claim Stage, the third-party team opens the trading switch, allowing tokens to be transferred freely and traded.

+ During this stage, the market-making profits generated by the LP locked in the FFLauncher contract will be obtained by the third-party team, constituting the funds raised by the third-party team.

### LP Settlement Stage

+ Once the LP lockup period expires, users can call the claimPoolLP method of the FFLauncher contract to withdraw the LP tokens locked during the Claim Stage. The third-party team will no longer receive LP market-making profits.
