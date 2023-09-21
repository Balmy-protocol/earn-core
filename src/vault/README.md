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
  shares(John) & = deposit * totalShares / totalAmount \notag \\
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
owned(John, DAI) = [totalAmount(DAI) - protocolFees(DAI)] * shares(John) / totalShares
$$

So for example, if the total amount of _$DAI_ increases to 15000, and no fees were charged, then:

$$
\begin{align}
owned(John, DAI) & = [totalAmount(DAI) - protocolFees(DAI)] * shares(John) / totalShares \notag \\
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
owned(John, OP) & = yielded(OP) * shares(John) / totalShares \notag \\
& = 50 * 250 / 2750 \notag \\
& \approx 4.54 \notag \\
\end{align}
$$

Now, the thing is that the total amount of shares changes over time. So, with each update, we would need to calculate
how much John owns by doing the same as before:

$$
\begin{align}
owned(John, OP) & = yielded_{t1 - t0}(OP) * shares(John) / totalShares_{t1} \notag \\
& \quad+ yielded_{t2 - t1}(OP) * shares(John) / totalShares_{t2}  \notag \\
& \quad+ yielded_{t3 - t2}(OP) * shares(John) / totalShares_{t3}  \notag \\
& \quad+ ... \notag \\
& = shares(John) * \sum_{n=1}^{\infty} [yielded_{tn-t(n-1)} / totalShares_{tn}]  \notag \\
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

#### Position Balance / Earned Fees

We believe that with 104 bits, we can store a single positions's balance (or, in the case of earned fees, the platform's
balance). Assuming 18 decimals, we can store up to _1e13_ units of tokens in it, which is enough to cover the entire
circulating supply of the top 1000 tokens in CoinMarketCap right now (Sep 15, 2023), except for _$APENFT_, _$BTT_,
_$SHIB_ and _$PEPE_. With all of them, we can cover up to 2% of the circulating supply, which is good enough for a
single position.

It's important to note that tokens that use a higher amount of decimals or have much bigger supplies might not fit
correctly. **It will be up to each strategy to make sure that reported tokens can work with these limitations**.

Also, let's remember that the total amount of balance will be stored with `uint256`, so we can handle these amounts when
accounting for all combined positions.

#### Yield Accumulator

Like we explained before, we can calculate a position's balance for non-asset tokens by calculating the sum of yielded
tokens divided by the amount of total shares. Like we said before, we'll use an accumulator to keep track of this sum,
instead of calculating it every time. But we need to be careful with the precision.

The accumulator is the sum of:

$$ yielded \* ACCUM_PRECISION / total(shares) $$

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
hold more than 0.25% of PEPE's circulating supply (Sep 15, 2023) before a wei is lost due to precision 🫡

##### Worst case analysis: overflow scenario

This would happen when we have big precision on yield, small precision on shares.

Assuming we are on a blockchain that has one-second blocks, how much space do we have in the accum before it overflows?
Let' assume that we want to make sure this contract works for at least the next 10 years (because in 10 years we'll
probably be using Solana anyways, right? 😂).

There are _3.154e8_ seconds in 10 years, which means there will be _3.154e8_ blocks. Assuming a **really** worst case
scenario of one update per block, we have:

$$
\begin{align}
max\_size(update) & < total\_space / max\_amount(updates) \notag \\
& < 2^{152} / 3.154e8 \notag \\
& < 1.81e37 \notag \\
\end{align}
$$

So, we know that:

$$
\begin{align}
yielded * ACCUM\_PRECISION / total(shares) & < max\_size(update) \notag \\
yielded * 1e33 / total(shares) & < 1.81e37 \notag \\
yielded / total(shares) & < 18100  \notag \\
\end{align}
$$

Let's assume that the asset is a low decimals token like USDC, and there are 10 USDC deposited. `1 asset ~ 1e3 shares`.
So we have `10 * 1e6 * 1e3` shares, which is _1e10_.

$$
\begin{align}
yielded / total(shares) & < 18100  \notag \\
yielded / 1e10 & < 18100  \notag \\
yielded & < 18100 * 1e10  \notag \\
yielded & < 1.81e14  \notag \\
\end{align}
$$

This means that if 10 USDC worth of tokens generate less than _1.8e14_ worth of tokens **per second**, then we have at
least 10 years before the accum overflows.

To put it in _$OP_ terms (known for its use as a reward), that would be
$0.00025 (Sep 15, 2023) usd per second, which would
be $21.6 usd per day. Not bad for a 10 _$USDC\_ deposit 😂

Again, tokens with more decimals or higher supplies might be closer to an overflow than the examples we just layed out,
but **it will be up to each strategy to make sure that the tokens they support work correctly with these limitations**.
