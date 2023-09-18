# Earn

Earn is Balmy's universal adapter for yield generating vaults. [ERC-4626](https://eips.ethereum.org/EIPS/eip-4626) does
a pretty good work of defining how yield vaults should look like, but it doesn't cover all cases. For example, some
vaults have rounds, where the user can't withdraw until the round is over. In other cases, like LSTs, withdrawals can
take a few days to be processed. And finally, there are cases where rewards are generated in tokens that are different
from the one deposited. So the idea is to try to define an universal way of generating and collecting this
yield/rewards.

In Earn, a user deposits an "asset" and immediately starts generating yield in one or more tokens (one of these tokens
could also be the same asset they deposited). When a user deposits their funds, they can choose the "strategy" they'd
like to use to generate this yield. Earn strategies are in charge of taking the asset and start generating yield, so
they will be the ones having control over all user funds. Strategies will normally take the asset and deposit it into
one or more "farms", to generate the yield. It will be up to each user to do their own due diligence and select their
preferred strategy, based on their own risk/reward inclinations.

When a user first deposit's into Earn, a "position" will be created to track their balances over time. Positions are
represented with NFTs, so they can be transferred. There is also a permission system in place that would allow owners to
grant specific permissions to other accounts. Positions can also be modified over time. For example, the owner (or
accounts with explicit permissions) could withdraw funds or deposit more assets into it.

## Definitions

### Vault

Earn's vault is the place where users deposit and withdraw their funds and rewards. Earn has a singleton vault contract,
which will be the one that keeps track of who owns what. It is also the one that implements access control and makes
sure that users can only access their own funds.

### Position

In order to use Earn, users will have to create a position. A position simply keeps track of the funds deposited and
earned by the user, in the context of a specific strategy. Once a position has been created, it can't change the chosen
strategy later.

Positions are represented with NFTs, so they can be transferred. There is also a permission system in place that would
allow owners to grant specific permissions to other accounts. Positions can also be modified over time. For example, the
owner (or accounts with explicit permissions) could withdraw funds or deposit more assets into it.

### Asset

When we talk about an asset, we refer to a token (could be ERC20 or native) that is deposited by the user to start
generating yield

### Strategies

In Earn, a strategy will take an asset and generate yield with it by depositing into one or more "farms". The generated
yield could be in the same asset, or in other tokens. One strategy could generate yield on multiple tokens at the same
time

Each strategy will have its own logic and risks associated with it. They might use leverage or maybe have some custom
safety features, the possibilities are endless. It will be up to each user to do their own due diligence and select
their preferred strategy, based on their own risk/reward inclinations

Strategy devs, please refer to [src/interfaces/IEarnStrategy.sol](src/interfaces/IEarnStrategy.sol) to understand
important restrictions to be considered when building your own strategy

#### Strategy Registry

When a position is created, users will have to choose a strategy to generate yield with. In reality, they will be
associating their funds to a "strategy id" that itself references a strategy contract.

It could happen that the owner of the strategy wants to upgrade their strategy, so that the strategy id points to a
different contract. When that happens, they will simply have to go to the strategy registry and propose a "strategy
update". Then, after a certain delay has passed, the owner will be able to execute the update. As part of the process,
the old vault will be told by the registry that it should migrate all funds over to the new strategy.

It's important to note that even though we have this delayed upgrade mechanism in place, a strategy might simply
implement their own upgradeability process that has no delay at all. So please be careful when selecting a strategy for
your funds.

### Farm

A farm is simply a name for a third party that will be used to generate yield with. Some examples could be:

- Aave
- Yearn
- Lido
- etc

### Delayed Withdrawals

Sometimes farms can implement a lock up periods for withdrawals. In that case, when a user wants to execute a
withdrawal, the strategy will call a "delayed withdrawal" adapter to handle the process. It goes without saying that
each "delayed withdrawal" will be associated to a position so that only accounts with permissions can retrieve the funds
later

#### Delayed Withdrawal Adapter

When a delayed withdrawal is started, the strategy will delegate the process to an delayed withdrawal adapter. Each
adapter will know how to handle withdrawals with one or more farms. We chose this approach of separating this process
from the strategy mainly for two reason:

1. To be able to re-use withdrawal adapters with various different strategies
2. So that we don't have to worry about migrating delayed withdrawals when a strategy is updated

#### Delayed Withdrawal Manager

When a delayed withdrawal is started, the Earn strategy will delegate the withdrawal to a delayed withdraw adapter. That
adapter is the one that will start the withdraw, and then register itself to the manager. By doing so, we will be able
to track all pending withdrawals for a specific position in one place

### Special Withdrawals

In some cases a user might want to perform a "special withdrawal". For example, if the farm were to implement a lock up
period, the user might prefer to withdraw the farm token directly and sell it on the market for a small loss, instead of
waiting

It will be up to each strategy to support one or more of these special withdrawals

Please refer to [src/types/SpecialWithdrawals.sol](src/types/SpecialWithdrawals.sol) to understand how to execute and
interpret these withdrawals correctly

### Fee Manager

## Architecture Summary

This is a small summary of how Earn's architecture looks like. Please take into account that when we refer to "Strategy
X", "Adapter Y" or "Farm Z" we are talking about one instance of each entity, but there are many who perform the same
job

```mermaid
flowchart
    user[User]
    admin[Balmy Admin]
    owner[Strategy Owner]

    subgraph earn[Earn]
      vault(Earn Vault)

      subgraph strategies[Strategies]
        strategy(Strategy X)
        registry(Strategy Registry)
      end

      subgraph delayed[Delayed Withdrawals]
        manager(Delayed Withdrawal\n Manager)
        adapter(Adapter Y)
      end
    end

    subgraph farms[Farms]
      farm(Farm Z)
    end

    user --->|Deposits/Withdraws|vault
    user --->|Withdraws After\nDelay|manager
    admin --->|Pauses deposits|vault
    owner --->|Register/Updates\nStrategy|registry
    owner --->|Updates Owner|registry
    owner --->|Emergency Actions|strategy
    registry --->|Informs Migration|strategy
    vault --->|Finds Strategy\nby Id|registry
    vault --->|Deposits/Withdraws|strategy
    strategy --->|Deposits/Withdraws|farm
    strategy --->|Assigns Delayed\nWithdrawal|adapter
    adapter --->|Starts and Tracks\n Delayed Withdrawals|farm
    adapter --->|Registers itself\nto position\nand strategy|manager
    manager --->|Withdraws|adapter
    manager --->|Checks Permissions|vault

```

## Usage

This is a list of the most frequently needed commands.

### Build

Build the contracts:

```sh
$ forge build
```

### Clean

Delete the build artifacts and cache directories:

```sh
$ forge clean
```

### Compile

Compile the contracts:

```sh
$ forge build
```

### Coverage

Get a test coverage report:

```sh
$ forge coverage
```

### Format

Format the contracts:

```sh
$ forge fmt
```

### Gas Usage

Get a gas report:

```sh
$ forge test --gas-report
```

### Lint

Lint the contracts:

```sh
$ pnpm lint
```

### Test

Run the tests:

```sh
$ forge test
```

## License

TBD
