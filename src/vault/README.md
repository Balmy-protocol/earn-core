# Earn Vault

Welcome to Balmy's Earn vault! 👋

Before diving into the code, we wanted to explain a little bit what the vault does, and how it works. We recommend going
over all of [Earn's definitions](../../README.md) if you haven't already.

Earn's vault is singleton contract that holds all of Earn's positions in one place. It keeps track of who owns what, and
also makes sure that users can only access their own funds.

## How does the vault keep track of the funds that belong to each user?

When a user deposits their assets into the vault, they will be assigned a number of shares based on the deposited amount
and the total amount of assets in the strategy they chose.

For example, let's say that:

- Total amount of _$DAI_ in strategy: 10000
- Total amount of shares in strategy: 2500

And then comes John, and deposits 1000 _$DAI_ into the strategy. He will be awarded 250 shares:

$$
\begin{align}
  shares(John) & = \frac{deposit * totalShares}{totalAmount} \notag \\
  & = 1000 * 2500 / 10000 \notag \\
  & = 250 \notag \\
\end{align}
$$

Then, we can say that :

- Total amount of _$DAI_ in strategy: 11000
- Total amount of shares in strategy: 2750
- Shares assigned to John: 250

### Owned assets

Now that we know how shares are assigned during deposits, we can easily calculate how much each user owns when the total
amount of _$DAI_ increases/decreases.

$$
owned(John, DAI) = \frac{totalAmount(DAI) * shares(John)}{totalShares}
$$

So for example, if the total amount of _$DAI_ increases to 15000, then:

$$
\begin{align}
owned(John, DAI) & = \frac{totalAmount(DAI) * shares(John)}{totalShares} \notag \\
& = [15000 - 0] * 250 / 2750 \notag \\
& = 15000 * 250 / 2750 \notag \\
& \approx 1363.63 \notag \\
\end{align}
$$

Pretty good increase from the original deposit! 🤑

### Other owned tokens

Let's remember that when a user deposits assets into Earn, they'll start earning yield in one or more tokens. One of
these tokens could be the asset, but they could be other tokens also.

Calculating who owns what in these others tokens is a little harder than the asset. Let's go over it with an example.
Let's say that when John last deposited into the strategy, there were 50 _$OP_ rewards already collected. Then, after a
few days, there were 100 _$OP_ rewards collected in total. That's 50 _$OP_ rewards generated since John's deposit. So,
how much of that belongs to John?

$$
\begin{align}
owned(John, OP) & = \frac{yielded(OP) * shares(John)}{totalShares} \notag \\
& = 50 * 250 / 2750 \notag \\
& \approx 4.54 \notag \\
\end{align}
$$

Now, the thing is that the total amount of shares changes over time. So, with each update, we would need to calculate
how much John owns by doing the same as before:

$$
\begin{align}
owned(John, OP) & = \frac{yielded_{t1 - t0}(OP) * shares(John)}{totalShares_{t1}} \notag \\
& \quad+ \frac{yielded_{t2 - t1}(OP) * shares(John)}{totalShares_{t2}}  \notag \\
& \quad+ \frac{yielded_{t3 - t2}(OP) * shares(John)}{totalShares_{t3}}  \notag \\
& \quad+ ... \notag \\
& = shares(John) * \sum_{n=1}^{\infty} \frac{yielded_{tn-t(n-1)}}{totalShares_{tn}}  \notag \\
\end{align}
$$

Now that we have this formula, we can simply store keep track of this sum by using an accumulator. When a position is
modified, we'll store the current accumulator value and associate it when a position. Then, in the future, we can do
`accum(current) - accum(stored for position)` to end up with the sum we needed.

_Note: there are some nuances in the actual implementation since we would only need to consider from $t_d$ (when John
makes a deposit). At the same time, we would also need to consider that John's shares could also change over time. But
the overall idea is the one explained here._ 🤓

## Technical Choices / Limitations

### Virtual Shares

Like we said before, we are using shares to keep track of how assets should be distributed between the different
positions. While easy to implement, this approach opens the door to "inflation attacks". In order to mitigate this kind
of attack, we will be using a "virtual shares" strategy. You can read more about this attack and our defense strategy
[here](https://blog.openzeppelin.com/a-novel-defense-against-erc4626-inflation-attacks) and
[here](https://docs.openzeppelin.com/contracts/4.x/erc4626#inflation-attack).

Now, for our contract in particular, we'll be starting with a `1 asset = 1e3 shares` offset. We chose this value
because:

- We felt it was enough to reduce the impact of inflation attacks
- It would also help increase precision on low decimal tokens
- It wasn't high enough to affect precision accounting (more on this explained below)

### Precision

When working with tricky math like we explained before, it's very important that we don't lose precision. At the same
time, we'd like to use the least amount of storage possible, so that all interactions continue to be cheap to execute.

You can refer to [this file](./types/Storage.sol) to understand the different variable sized we chose.

#### Position Balance

We believe that with 102 bits, we can store a strategy's balance. Assuming 18 decimals, we can store up to _5e11_ units
of tokens in it, which is enough to cover the entire circulating supply of ~95% of the top 1000 tokens in CoinMarketCap
right now (Sep 20, 2023), except for mostly meme coins. At the same time, it's enough to cover up to 1.5% of _$PEPE_'s
circulating supply, which is good enough for a single strategy. Let's remember that if a strategy is filled, then an
exact copy can be deployed to manage more funds.

It's important to note that tokens that use a higher amount of decimals or have much bigger supplies might not fit
correctly. **It will be up to each strategy to make sure that reported tokens can work with these limitations**.

#### Yield Accumulator

Like we explained before, we can calculate a position's balance for reward (non-asset) tokens by calculating the sum of
yielded tokens divided by the amount of total shares. Like we said before, we'll use an accumulator to keep track of
this sum, instead of calculating it every time. But we need to be careful with the precision.

The accumulator is the sum of:

$$ \frac{yielded \* ACCUM_PRECISION}{total(shares)} $$

We add `ACCUM_PRECISION` so that if the yield is low, we don't lose precision. Before starting with the analysis, let's
remember that we are using a virtual assets approach, so let's assume that `1 asset ~ 1e3 shares`.

##### Worst case analysis: precision loss scenario

This would happen when we have big precision on shares, small precision on yield. For example, let's say that we are
using _$DAI_ for asset. We know that 1 _$DAI_ wei starts at _1e3_ shares. And let's say that there is 100m worth of
_$DAI_ deposited, so we have ~`1e8 * 1e18 * 1e3` shares, which is _1e29_.

Now, if we yielded 0.01 USDC, that is _1e4_. So `1e4 * ACCUM_PRECISION / 1e29` needs to be > 1, or we'll lose the yield
due to precision.

$$
\begin{align}
1e4 * ACCUM\_PRECISION / 1e29 & > 1 \notag \\
 ACCUM\_PRECISION & > 1e29 / 1e4 \notag \\
 ACCUM\_PRECISION & > 1e25 \notag  \\
\end{align}
$$

We'll go with `ACCUM_PRECISION = 1e33` so that we can support even smaller amounts of USDC but let's understand the
limitations a little more. In order to be able to track 1 wei of yield, we need to

$$
\begin{align}
1 * ACCUM\_PRECISION / total(shares) & > 1 \notag \\
total(shares) & < ACCUM\_PRECISION \notag \\
total(shares) & < 1e33 \notag \\
\end{align}
$$

Since we assume that `1 asset ~ 1e3 shares`, then we know that:

$$
\begin{align}
total(shares) & < 1e33 \notag \\
1e3 * total(assets) & < 1e33 \notag \\
total(assets) & < 1e33 / 1e3 \notag \\
total(assets) & < 1e30 \notag \\
\end{align}
$$

If the total amount of assets is over _1e30_, then we might start to lose some precision. With 18 decimals, that's
_1e12_ units of tokens we can have deposited on the strategy. To put it in easier terms, a single strategy would have to
hold more than 0.25% of _$PEPE_'s circulating supply (Sep 20, 2023) before a wei is lost due to precision 🫡

##### Worst case analysis: overflow scenario

This would happen when we have big precision on yield, small precision on shares.

Assuming we are on a blockchain that has one-second blocks, how much space do we have in the accum before it overflows?
Let' assume that we want to make sure this contract works for at least the next 10 years (because in 10 years we'll
probably be using Solana anyways, right? 😂).

There are _3.154e8_ seconds in 10 years, which means there will be _3.154e8_ blocks. Assuming a **really** worst case
scenario of one update per block, we have:

$$
\begin{align}
max\_size(update) & < \frac{total\_space}{max\_amount(updates)} \notag \\
& < \frac{2^{150}}{3.154e8} \notag \\
& < 4.52e36 \notag \\
\end{align}
$$

So, we know that:

$$
\begin{align}
\frac{yielded * ACCUM\_PRECISION}{total(shares)} & < max\_size(update) \notag \\
\frac{yielded * 1e33}{total(shares)} & < 4.52e36 \notag \\
\frac{yielded}{total(shares)} & < 4520  \notag \\
\end{align}
$$

Let's assume that the asset is a low decimals token like USDC, and there are 10 USDC deposited. `1 asset ~ 1e3 shares`.
So we have `10 * 1e6 * 1e3` shares, which is _1e10_.

$$
\begin{align}
yielded / total(shares) & < 4520  \notag \\
yielded / 1e10 & < 4520  \notag \\
yielded & < 4520 * 1e10  \notag \\
yielded & < 4.52e13  \notag \\
\end{align}
$$

This means that if 10 USDC worth of tokens generate less than _4.52e13_ worth of tokens **per second**, then we have at
least 10 years before the accum overflows.

To put it in _$OP_ terms (known for its use as a reward), that would be
$0.00006 (Sep 20, 2023) usd per second, which would
be $5.2 usd per day. Not bad for a 10 _$USDC\_ deposit 😂

Again, tokens with more decimals or higher supplies might be closer to an overflow than the examples we just layed out,
but **it will be up to each strategy to make sure that the tokens they support work correctly with these limitations**.

### Yield Losses

First, a few notes on losses. Today in DeFi, reward tokens are mostly received as a reward for providing liquidity, as a
form of liquidity mining. These rewards tend to be distributed based on amount of liquidity, and the amount of rewards
tends to increase over time until all the rewards are assigned. As a general rule, these rewards don't tend to diminish
over time, only increase. There could be a few scenarios where a loss happens, like hacks or if a protocol removes all
rewards that were unclaimed after a long period of time. But we believe that generally, there shouldn't be any losses in
reward tokens.

So far, we've described how we can calculate how much each position has earned for reward tokens. The approach is
simple, but it has its limitations. For example, it does not handle correctly a scenario where there might be a loss
between to updates. Let's see an example:

```
Moment 0
- Total rewards: 0 $OP
- John deposits and is assigned 100 shares
- yieldAccum = 0

Moment 1
- Total rewards: 100 OP
- Peter deposits and is assigned 200 shares
- yieldAccum = 0 + (100 - 0) / 100 = 1

Moment 2
- Total rewards: 400 OP
- Alice deposits and is assigned 50 shares
- yieldAccum = 1 + (400 - 100) / 300 = 1 + 300 / 300 = 2

How much is assigned to each user?
- John = (2 - 0) * 100 = 200 OP
- Peter = (2 - 1) * 200 = 200 OP
- Alice = (2 - 2) * 5 = 0

Moment 3
- Total rewards: 50 OP
- yieldAccum = 2 + (50 - 400) / 350 = 2 - 1 = 1

How much is assigned to each user?
- John = (1 - 0) * 100 = 100 OP
- Peter = (1 - 1) * 200 = 0 OP
- Alice = (1 - 2) * 50 = -50 OP
```

We can see that it doesn't add up 😅 The problem is that earnings can be distributed to everyone based on shares, but
losses need to be distributed according to what they had earned so far. What would we want the balances to look like?
Ideally, we would distribute the losses based on what each user had earned on the previous snapshot, to achieve this
we'll need to apply the losses to the yieldAccum so we'll use an accumulator to keep track of this losses. Something
like this:

$$ balance(user) = earned(user, last\ snapshot) \ast lossRatio + yield(since\ last\ snapshot) $$

with:

$$
lossRatio =
\frac{lossAccum} {lossAccumInitial}
$$

$$ yield(since\ last\ snapshot) = shares \ast (yieldAccum - yieldAccumInitial \ast lossRatio) $$

By doing this, we're applying the losses to the already calculated balance. And we also need to apply them to what was
yielded after the last snapshot. Losses have been successively applied to the strategy's yieldAccum, so it's necessary
to apply them to the yieldAccumInitial, the one who belongs to the position.

So, what would it look like?

```
Moment 0
- Total rewards: 0 $OP
- John deposits and is assigned 100 shares
- yieldAccum = 0

Moment 1
- Total rewards: 100 OP
- Peter deposits and is assigned 200 shares
- yieldAccum = 0 + (100 - 0) / 100 = 1

Moment 2
- Total rewards: 400 OP
- Alice deposits and is assigned 100 shares
- yieldAccum = 1 + (400 - 100) / 300 = 1 + 300 / 300 = 2

How much is assigned to each user?
- John = (2 - 0) * 100 = 200 OP
- Peter = (2 - 1) * 200 = 200 OP
- Alice = (2 - 2) * 100 = 0

Moment 3
- Total rewards: 100 OP
- yieldAccum = yieldAccum * 100 / 400 = 2 * 100 / 400 = 0.5
- lossAccum = 0.25

How much is assigned to each user?
- John = (yieldAccum - yieldAccumInitial * lossAccum) * shares
       = (0.5 - 0 * 0.25) * 100 = 50
- Peter = (yieldAccum - yieldAccumInitial * lossAccum) * shares
        = (0.5 - 1 * 0.25) * 200 = 50
- Alice = (yieldAccum - yieldAccumInitial * lossAccum) * shares
        = (0.5 - 2 * 0.25) * 100 = 0

Moment 4:
- Total reward: 200 OP
- yieldAccum = yieldAccum + yielded / total shares
             = 0.5 + 100 OP / 400
             = 0.75

- John = (yieldAccum - yieldAccumInitial * lossAccum) * shares
       = (0.75 - 0 * 0.25) * 100 = 75
- Peter = (yieldAccum - yieldAccumInitial * lossAccum) * shares
        = (0.75 - 1 * 0.25) * 200 = 100
- Alice = (yieldAccum - yieldAccumInitial * lossAccum) * shares
        = (0.75 - 2 * 0.25) * 100 = 25

Moment 5:
- Total reward: 400 OP
- yieldAccum = yieldAccum + yielded / total shares
             = 0.75 + 200 OP / 400
             = 1.25

- John = (yieldAccum - yieldAccumInitial * lossAccum) * shares
       = (1.25 - 0 * 0.25) * 100 = 125
- Peter = (yieldAccum - yieldAccumInitial * lossAccum) * shares
        = (1.25 - 1 * 0.25) * 200 = 200
- Alice = (yieldAccum - yieldAccumInitial * lossAccum) * shares
        = (1.25 - 2 * 0.25) * 100 = 75

Moment 6:
- Total reward: 80 OP
- Joseph deposits and is assigned 400 shares
- yieldAccum = yieldAccum * 80 / 400
             = 1.25 * 80 OP / 400
             = 0.25
- lossAccum = lossAccum * 80 / 400
               = 0.05

- John = (yieldAccum - yieldAccumInitial * (lossAccum / lossAccumInitial)) * shares
       = (0.25 - 0 * 0.05) * 100 = 25
- Peter = (yieldAccum - yieldAccumInitial * lossAccum) * shares
        = (0.25 - 1 * 0.05) * 200 = 40
- Alice = (yieldAccum - yieldAccumInitial * lossAccum) * shares
        = (0.25 - 2 * 0.05) * 100 = 15

Moment 7:
- Total rewards: 160 OP
- yieldAccum = yieldAccum + yielded / total shares
             = 0.25 + 80 / 800 = 0.35
- John = (yieldAccum - yieldAccumInitial * (lossAccum / lossAccumInitial)) * shares
       = (0.35 - 0 * (0.05 / 1)) * 100 = 35
- Peter = (yieldAccum - yieldAccumInitial * lossAccum) * shares
        = (0.35 - 1 * (0.05 / 1)) * 200 = 60
- Alice = (yieldAccum - yieldAccumInitial * lossAccum) * shares
        = (0.35 - 2 * (0.05 / 1)) * 100 = 25
- Joseph = (yieldAccum - yieldAccumInitial * lossAccum) * shares
        = (0.35 - 0.25 * (0.05 / 0.05)) * 400 = 40
```

#### Loss accumulator precision

Since the loss accumulator is successively multiplied, to avoid under/overflow, we had two alternatives: start it at its
maximum value and then decrease it or take the inverse approach. We chose for the first option as it handles rounding
better.

#### Storing Complete Losses

We just described how to take losses into account when calculate a position's balance for reward tokens. However, when a
complete loss occurs, the loss accumulator multiplies down to zero and stays there. The approach requires storing a
counter to track when there was a complete loss, so that each position can compare over them and calculate the
position's balance after the complete loss has been accounted for.

We will leave it **up to each strategy to try to avoid complete losses as much as possible**. The vault is prepared to
support **up to 15** complete loss events per token, for each strategy. This should be enough to cover for unexpected
circumstances such as hacks, but it's very important that the strategy avoids complete losses as much as possible.

After the 15 complete losses limit has been reached, the vault will simply set all position balances to zero. It will be
up to each strategy to distribute any left funds in a way they deem fit.
