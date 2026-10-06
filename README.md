# Dev Is A Robot — NODEV

This is the contract-stage implementation of the approved **Dev Is A Robot** launch. The only deployable project contract is `src/LaunchToken.sol:LaunchToken`. It is a plain ERC-20 built on the vendored OpenZeppelin Contracts v5.0.2 implementation.

| Property | Fixed value |
| --- | --- |
| Name | `Dev Is A Robot` |
| Symbol | `NODEV` |
| Decimals | `18` |
| Total supply | `1,000,000,000 NODEV` |
| Supply in minor units | `1000000000000000000000000000` (`10^27`) |
| Constructor arguments | None (`[]`) |
| Constructor ETH value | `0`; nonpayable |
| Initial recipient | `msg.sender`, the deploying launch factory |
| Post-deployment initialization | None |
| Privileged roles | None |

The constructor mints the whole supply once and emits `Transfer(address(0), deployer, 10^27)`. There is no external mint or burn function, owner, administrator, pause, blocklist, tax, fee, transaction cap, wallet cap, upgrade mechanism, proxy, or custom Uniswap hook. OpenZeppelin's internal mint/burn helpers do not create external entrypoints; this contract calls `_mint` only in its constructor and never calls `_burn`.

## Local build and checks

Install Foundry and make Solidity **0.8.26** available to it. All Solidity dependencies required for compilation and testing are ordinary files in `lib/`; no package download, submodule, RPC, wallet, environment configuration, or deployment is needed to run the tests. The offline verifier supplies the compiler.

```sh
forge build
forge test
forge fmt --check
```

`foundry.toml` pins Solidity 0.8.26, the Paris EVM target, optimizer enabled with 200 runs, and `bytecode_hash = "none"`. FFI is disabled and filesystem cheatcode permissions are empty. The Paris target avoids requiring newer EVM opcodes. Compiler metadata contains no bytecode hash. Preserve these settings when building deployment artifacts.

Tests exercise metadata and supply, the constructor event, CREATE2 factory deployment, exact transfers, full-supply and self transfers, zero amounts, approvals, revocation, finite/infinite allowances, balance and allowance failures, atomic rollback, unauthorized spending, absent administrative entrypoints, nonpayability, recipients that reject callbacks, and runtime size/forbidden opcodes. Five fuzz tests run 512 cases each. Two stateful invariants run 128 sequences of 64 actions each, comparing all balances and allowances against an independent model for four holders. Tests create fresh fixtures, use no environment cheatcodes, and can run in parallel.

The ABI is exported at [`docs/abi/LaunchToken.json`](docs/abi/LaunchToken.json), with integration notes at [`docs/ABI.md`](docs/ABI.md). Regenerate it after source changes:

```sh
forge inspect src/LaunchToken.sol:LaunchToken abi --json > docs/abi/LaunchToken.json
```

Dependency origins, archive hashes, licenses and integrity verification are documented in [`docs/DEPENDENCIES.md`](docs/DEPENDENCIES.md).

## Deployment handoff

This is a **token-only `evm_project`**. The separate manifest contributor should identify `LaunchToken` as the launch token, with name `Dev Is A Robot`, symbol `NODEV`, 18 decimals and supply `10^27` minor units. The application `contracts` array is empty. No application constructor parameters, owner arguments, dependency addresses, linked libraries or initialization calls are needed. Test helpers are not deployment artifacts.

The deploying ProjectFactory must receive all tokens at construction. Do not deploy through an intermediate contract that retains the supply or replace the recipient with the launch requester's address. The factory performs distribution after deployment: 10% for the swarm (2% for accepted contributors and 8% for paired seats), and the other 90% for the requester, including the policy-selected liquidity allocation (80% of total supply by default). None of those percentages is implemented in the token. The approved token requirements need no deviations.

The request does not choose another pair currency, so the manifest guidance defaults to native ETH (zero address), with admission fields `fee = 3000`, `tickSpacing = 60`, and `initialPrice = "79228162514264337593543950336"`. The service's pinned policy determines the effective opening price. The actual trading fee comes from the network's LaunchFees contract (1.25% by default, split 1% to the launch payer and 0.25% to IMD); these are protocol pool settings, not token taxes. The factory supplies the distributor and initialization-only pool guard. This contribution supplies neither of those contracts nor a swap hook.

The manifest stage owns `launch.json`. The final independent reviewer checks the accepted source and completed manifest. Services own publication, signed artifact/policy linkage, attestation, admission, deployment and explorer verification. No network addresses or final deployment addresses were supplied here; the deployment service resolves them from the canonical network configuration and handoff. No transactions have been broadcast by this project.

After deployment, services hand the frontend the actual chain, token address, ABI, exact poolKey, and published source URL. The approved terminal website, wallet balance display, live pool price, diagnostics, thought log and “Fire the Dev” interaction belong to the subsequent frontend stage. Pool price comes from the deployed pool; this token exposes no price oracle. This deliverable does not assert that the source has already been published, that the website is hosted on IPFS, or that contracts have been deployed.

## Operational assumptions

Any holder can transfer and set allowances. A spender can move only tokens covered by that holder's allowance. The deployer has no permanent authority over other holders. There are no external calls in token operations and no recipient callback mechanism.

Zero-value transfers to nonzero addresses succeed and emit `Transfer`. Transfers to zero and approvals to a zero spender revert. A self-transfer requires sufficient balance and preserves it; delegated self-transfers consume finite allowances. An allowance of `type(uint256).max` is unlimited and is not reduced by `transferFrom`. `approve` replaces the existing allowance; clients should account for the standard allowance-change transaction-ordering race, normally by confirming revocation to zero before granting a replacement. Read `allowance` for current state: `transferFrom` does not emit an `Approval` event in this implementation.

The contract does not accept ordinary ETH transfers and has no recovery mechanism. Forced ETH, tokens sent to the token contract, and tokens sent to inaccessible addresses cannot be recovered by an administrator. Transfers to arbitrary nonzero contracts are permitted; ERC-20 does not verify recipient capability. The fixed total supply counts inaccessible balances too. No keeper, oracle, randomness provider, or privileged operational key is needed for token behavior.

Local tests are not an independent audit. An independent contributor's adversarial review of source and manifest remains the release responsibility of the next stage. Foundry build, unit/fuzz/invariant tests and formatting checks are the local validation tools; Slither and Mythril were not run.

Meme token. No promises. Not financial advice.
