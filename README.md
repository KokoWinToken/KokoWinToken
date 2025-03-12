KokoWinToken Smart Contract Documentation

1. Overview

Token Name: KokoWin
Token Symbol: KOKO
Decimals: 18
Total Supply: Set at deployment (_initialSupply * 10^18)
Owner: The address that deploys the contract

The KokoWinToken contract implements standard TRC20 functions (similar to ERC20) and includes additional functionality for staking with bonus rewards, bonus pool updates according to a preset schedule, and a burn function.



2. Data Storage

2.1 Basic Token Information

name, symbol, decimals, totalSupply: Basic details about the token.

owner: The address that deploys the contract.

stakingPool: The number of tokens allocated for bonus payments to stakers.

2.2 Token Balances and Permissions

balanceOf: A mapping that stores the token balance for each address.

allowance: A mapping that defines how many tokens an owner has allowed a spender to withdraw.

lockedUntil: A mapping that defines the timestamp until which tokens on a given address are locked.

2.3 Staking Variables

stakedAmount: A mapping of the amount of tokens staked by each user.

stakingStart: A mapping that records the timestamp when staking started for each user.

totalStakers: The total number of active stakers.

MAX_STAKERS: The maximum number of stakers allowed (set to 100,000).

2.4 Bonus Variables (Internal)

bonusTime1, bonusTime2, bonusTime3: Unix timestamps for one-time bonus events on May 16, 2028; May 16, 2030; and May 16, 2032 respectively.

bonus1Added, bonus2Added, bonus3Added: Boolean flags indicating whether the corresponding bonus has already been added.

bonusAmount1, bonusAmount2, bonusAmount3: The bonus amounts for the corresponding dates (accounting for decimals): 

BonusAmount1 = 5,707,298 tokens

BonusAmount2 = 2,853,649 tokens

BonusAmount3 = 1,426,825 tokens

subsequentBonusAmount: After bonusTime3, 1,000,000 tokens are minted every 2 years on May 16.

subsequentBonusPeriodsAdded: A counter for the bonus periods after bonusTime3 that have already been processed.

2.5 Private Text Message

CONTRACT_MESSAGE: A private string containing a description of the contract. It is stored in the bytecode and does not affect the contract's functionality, but it increases the bytecode size.



3. TRC20 Standard Functions

3.1 transfer

Allows transferring tokens from the sender's address to another address. It checks that the tokens are not locked (using lockedUntil).
This function decreases the sender's balance and increases the recipient's balance, and then emits a Transfer event.

3.2 approve

Allows the token owner to set an allowance for another address (spender), authorizing them to spend up to a specified amount of tokens from the owner’s account.
The approved amount is stored in the allowance mapping.

3.3 transferFrom

Allows the spender to transfer tokens from the owner’s account, given that the owner has previously approved this transfer via approve.
The function checks that the allowed amount is sufficient and then updates the balances accordingly, emitting a Transfer event.



4. Staking Mechanism

4.1 stake

Allows a user to stake a specified amount of tokens:

Checks that the staking amount is greater than zero.

Verifies that the user has enough tokens and is not already staking (to prevent multiple simultaneous stakes).

Transfers the tokens from the user to the contract.

Records the staked amount and the staking start time.

Increments the total staker count and emits a Staked event.

4.2 unstake

Allows a user to withdraw their staked tokens along with a bonus reward calculated dynamically based on the staking duration (APR):

APR Calculation: 

Less than 60 days – 5% per annum.

60 to 120 days – 10% per annum.

120 to 180 days – 15% per annum.

180 to 240 days – 20% per annum.

240 days and more – 25% per annum.

The bonus is calculated as: 

ini

Копировать

calculatedReward = (stakedAmount * effectiveRate * stakingTime) / (365 days * 100)

If the staking pool (stakingPool) contains enough bonus tokens, the full bonus is awarded; otherwise, the available bonus is used.

The function then transfers the total (staked tokens + bonus) back to the user, updates the staking pool, and emits an Unstaked event.

4.3 depositToPool

Allows any user to deposit tokens into the staking pool, increasing the pool available for bonus payouts.



5. Bonus Pool Update Mechanism

updateStakingPool

This function updates the staking pool according to the bonus schedule:

One-time Bonuses: 

On May 16, 2028; May 16, 2030; and May 16, 2032, bonus tokens are minted and added to totalSupply, the contract’s balance, and stakingPool.

Corresponding boolean flags (bonus1Added, bonus2Added, bonus3Added) are set to prevent multiple bonus awards.

Subsequent Bonuses: 

After May 16, 2032, the function calculates how many bonus periods (every 2 years on May 16) have passed.

For each bonus period that has passed, 1,000,000 tokens are minted and added to the overall supply and stakingPool.

The function uses the helper function toTimestamp for accurate date conversion (taking leap years into account).

Note: This function must be called manually (or via an automated service) to update the bonus pool.



6. Burn Function

burn

Allows a user to burn (destroy) a specified amount of tokens, which reduces both the user's balance and the totalSupply.

The function is available only after July 30, 2030 (Unix timestamp 1911600000).

Emits a Burn event and a Transfer event (with the recipient set to address 0).



7. Helper Functions for Date Calculations

isLeapYear

Determines whether a given year is a leap year.

toTimestamp

Calculates the Unix timestamp for a given calendar date (year, month, day).

It iterates from 1970 to the given year, summing the number of days (taking into account leap years), then adds the days for the months and the day offset.

Finally, it multiplies the total days by the number of seconds in a day to obtain the timestamp.



8. Additional Comments

CONTRACT_MESSAGE: This private string is embedded in the contract's bytecode and is not visible through standard read functions. Its presence increases the bytecode size and, therefore, the deployment cost.

Gas Costs:
Functions that modify the state (transfers, staking, unstaking, bonus updates, burning) require gas. View functions (e.g., allowance) do not require gas when called externally.



9. Summary

The KokoWinToken smart contract:

Implements the TRC20 standard with functions for transfers, approvals, and delegated transfers.

Provides a staking mechanism where users can lock tokens and earn bonus rewards based on staking duration.

Updates the bonus pool on a fixed schedule: one-time bonuses on May 16, 2028; May 16, 2030; and May 16, 2032, followed by recurring bonuses every two years on May 16.

Offers a burn function to permanently remove tokens from circulation after a specific date.

Uses helper functions to accurately calculate dates (taking leap years into account).



