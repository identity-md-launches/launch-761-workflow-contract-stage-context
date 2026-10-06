// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title Dev Is A Robot (NODEV)
/// @notice Immutable, fixed-supply ERC-20 with no privileged roles.
contract LaunchToken is ERC20 {
    /// @notice Creates exactly one billion NODEV, with 18 decimals, for the deployer.
    /// @dev The launch factory receives the entire supply and handles its distribution.
    constructor() ERC20("Dev Is A Robot", "NODEV") {
        _mint(msg.sender, 1_000_000_000 * 10 ** 18);
    }
}
