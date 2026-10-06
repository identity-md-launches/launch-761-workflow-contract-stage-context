# LaunchToken ABI

[`abi/LaunchToken.json`](abi/LaunchToken.json) is the compiler-generated JSON ABI array for `src/LaunchToken.sol:LaunchToken`, compiled with Solidity 0.8.26 and the committed Foundry configuration. It includes the constructor, nine public ERC-20/metadata functions, two events and six ERC-20 custom errors. It contains no privileged, initialization, mint, burn or upgrade function.

The constructor has no arguments and is nonpayable. It creates exactly `10^27` minor units for its caller. There is no fallback or receive function. All amounts are unsigned integers in minor units; divide by `10^18` for displayed NODEV values.

| Call | Return | Behavior |
| --- | --- | --- |
| `name()` | `string` | `Dev Is A Robot` |
| `symbol()` | `string` | `NODEV` |
| `decimals()` | `uint8` | `18` |
| `totalSupply()` | `uint256` | Always `10^27` |
| `balanceOf(address account)` | `uint256` | Account balance; zero for unknown accounts |
| `allowance(address owner, address spender)` | `uint256` | Remaining spending authorization; initially zero |
| `transfer(address to, uint256 value)` | `bool` | Moves the caller's tokens and returns `true`; invalid transfers revert |
| `approve(address spender, uint256 value)` | `bool` | Replaces the caller's allowance and returns `true`; zero revokes |
| `transferFrom(address from, address to, uint256 value)` | `bool` | Moves authorized tokens, consumes finite allowance, and returns `true` |

All three state-changing functions are nonpayable. `transferFrom` requires allowance even when `from == msg.sender`. Unlimited (`uint256.max`) allowance stays unchanged after spending. Failed operations revert all state changes, including allowance deductions. Zero-value transfers between nonzero addresses succeed even without a positive balance or allowance.

| Event | Indexed fields | Data |
| --- | --- | --- |
| `Transfer(address from, address to, uint256 value)` | `from`, `to` | Amount; includes zero amounts and the constructor mint |
| `Approval(address owner, address spender, uint256 value)` | `owner`, `spender` | New allowance; emitted by `approve` |

Allowance reductions during `transferFrom` do not emit `Approval`. Consumers must read `allowance` rather than reconstruct it using only approval logs.

The error ABI includes `ERC20InsufficientBalance(address sender,uint256 balance,uint256 needed)`, `ERC20InsufficientAllowance(address spender,uint256 allowance,uint256 needed)`, `ERC20InvalidSender(address sender)`, `ERC20InvalidReceiver(address receiver)`, `ERC20InvalidApprover(address approver)`, and `ERC20InvalidSpender(address spender)`. A call violating multiple preconditions can fail on the first check (for example, allowance before recipient validation). Clients should not rely on a particular error priority.

The token follows [ERC-20](https://eips.ethereum.org/EIPS/eip-20), with implementation semantics provided by the pinned [OpenZeppelin ERC20 v5.0.2 source](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.2/contracts/token/ERC20/ERC20.sol). The implementation of `_spendAllowance` and `_approve` controls actual event behavior; some earlier comments in that upstream file still describe approval logs on spending.
