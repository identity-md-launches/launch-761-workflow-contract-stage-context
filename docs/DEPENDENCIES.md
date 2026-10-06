# Vendored dependencies

All dependency source files and licenses are included as ordinary files. No submodules, package installation, FFI or network access are required to compile or run tests once Foundry and the pinned compiler are available.

| Directory | Origin/version | Included content | License |
| --- | --- | --- | --- |
| `lib/openzeppelin-contracts/` | [OpenZeppelin Contracts v5.0.2](https://github.com/OpenZeppelin/openzeppelin-contracts/tree/v5.0.2) | Unmodified ERC20, IERC20, IERC20Metadata, Context and IERC6093 error interfaces | `lib/openzeppelin-contracts/LICENSE` (MIT) |
| `lib/forge-std/` | [forge-std v1.9.7](https://github.com/foundry-rs/forge-std/tree/v1.9.7) | Unmodified Solidity files under upstream `src/`; used only for tests | `lib/forge-std/LICENSE-MIT`, `lib/forge-std/LICENSE-APACHE` |

The exact downloaded archive URLs and SHA-256 hashes are recorded in `lib/DEPENDENCIES.txt`. `lib/checksums.sha256` records the hashes of every delivered dependency file and that origin record. Verify file integrity from the repository root:

```sh
sha256sum --check lib/checksums.sha256
```

Only the ERC-20 inheritance tree is used in production. No third-party contracts need to be deployed or linked. The dependency's internal `_mint` and `_burn` functions are not externally callable. `LaunchToken` introduces a constructor-only mint and exposes no supply-changing function.
