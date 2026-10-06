// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {LaunchToken} from "../src/LaunchToken.sol";

/// @dev Independent balance/allowance model over a closed set of four holders.
contract TokenHandler is Test {
    LaunchToken private immutable token;
    address[4] public actors = [address(0x1001), address(0x1002), address(0x1003), address(0x1004)];
    mapping(address => uint256) public modelBalance;
    mapping(address => mapping(address => uint256)) public modelAllowance;

    constructor(LaunchToken token_) {
        token = token_;
        modelBalance[actors[0]] = 1_000_000_000 * 10 ** 18;
    }

    function transfer(uint256 fromSeed, uint256 toSeed, uint256 amountSeed) public {
        address from = actors[fromSeed % 4];
        address to = actors[toSeed % 4];
        uint256 amount = bound(amountSeed, 0, modelBalance[from]);
        vm.prank(from);
        assertTrue(token.transfer(to, amount));
        modelBalance[from] -= amount;
        modelBalance[to] += amount;
    }

    function approve(uint256 ownerSeed, uint256 spenderSeed, uint256 amountSeed, bool unlimited) public {
        address owner = actors[ownerSeed % 4];
        address spender = actors[spenderSeed % 4];
        uint256 amount = unlimited ? type(uint256).max : bound(amountSeed, 0, type(uint256).max - 1);
        vm.prank(owner);
        assertTrue(token.approve(spender, amount));
        modelAllowance[owner][spender] = amount;
    }

    function transferFrom(uint256 fromSeed, uint256 toSeed, uint256 spenderSeed, uint256 amountSeed) public {
        address from = actors[fromSeed % 4];
        address to = actors[toSeed % 4];
        address spender = actors[spenderSeed % 4];
        uint256 approved = modelAllowance[from][spender];
        uint256 maximum = modelBalance[from] < approved ? modelBalance[from] : approved;
        uint256 amount = bound(amountSeed, 0, maximum);
        vm.prank(spender);
        assertTrue(token.transferFrom(from, to, amount));
        modelBalance[from] -= amount;
        modelBalance[to] += amount;
        if (approved != type(uint256).max) {
            modelAllowance[from][spender] -= amount;
        }
    }

    // Failed operations leave the model unchanged. The invariants then check
    // every holder and spender, including unrelated accounts, for atomic rollback.
    function overdraw(uint256 fromSeed, uint256 toSeed, uint256 amountSeed) public {
        address from = actors[fromSeed % 4];
        address to = actors[toSeed % 4];
        uint256 balance = modelBalance[from];
        uint256 amount = bound(amountSeed, balance + 1, type(uint256).max);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, from, balance, amount));
        vm.prank(from);
        token.transfer(to, amount);
    }

    function overdrawWithAllowance(uint256 fromSeed, uint256 spenderSeed, uint256 amountSeed, bool unlimited) public {
        address from = actors[fromSeed % 4];
        address spender = actors[spenderSeed % 4];
        address to = actors[(fromSeed % 4 + 1) % 4];
        uint256 balance = modelBalance[from];
        uint256 amount = bound(amountSeed, balance + 1, type(uint256).max - 1);
        uint256 approved = unlimited ? type(uint256).max : amount;
        _approve(from, spender, approved);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, from, balance, amount));
        vm.prank(spender);
        token.transferFrom(from, to, amount);
    }

    function spendPastAllowance(uint256 fromSeed, uint256 spenderSeed, uint256 allowanceSeed) public {
        address from = _fundedActor(fromSeed);
        address spender = actors[spenderSeed % 4];
        // The holder can afford this transfer, so only authorization can reject it.
        uint256 approved = bound(allowanceSeed, 0, modelBalance[from] - 1);
        _approve(from, spender, approved);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, approved, approved + 1)
        );
        vm.prank(spender);
        token.transferFrom(from, spender, approved + 1);
    }

    function rejectZeroRecipient(uint256 fromSeed, uint256 spenderSeed, uint256 amountSeed, bool delegated) public {
        address from = actors[fromSeed % 4];
        address spender = actors[spenderSeed % 4];
        uint256 amount = bound(amountSeed, 0, modelBalance[from]);
        if (delegated) {
            _approve(from, spender, amount);
        }
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        vm.prank(delegated ? spender : from);
        if (delegated) {
            token.transferFrom(from, address(0), amount);
        } else {
            token.transfer(address(0), amount);
        }
    }

    function rejectZeroSpender(uint256 ownerSeed, uint256 amount) public {
        address owner = actors[ownerSeed % 4];
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSpender.selector, address(0)));
        vm.prank(owner);
        token.approve(address(0), amount);
        assertEq(token.allowance(owner, address(0)), 0);
    }

    function revokeAndProbe(uint256 ownerSeed, uint256 spenderSeed) public {
        address owner = _fundedActor(ownerSeed);
        address spender = actors[spenderSeed % 4];
        _approve(owner, spender, 0);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, 0, 1));
        vm.prank(spender);
        token.transferFrom(owner, spender, 1);
    }

    function spendFullBalance(uint256 fromSeed, uint256 toSeed, uint256 spenderSeed, bool unlimited) public {
        address from = _fundedActor(fromSeed);
        address to = actors[toSeed % 4];
        address spender = actors[spenderSeed % 4];
        uint256 amount = modelBalance[from];
        _approve(from, spender, unlimited ? type(uint256).max : amount);
        vm.prank(spender);
        assertTrue(token.transferFrom(from, to, amount));
        modelBalance[from] -= amount;
        modelBalance[to] += amount;
        if (!unlimited) {
            modelAllowance[from][spender] = 0;
        }
    }

    function roundTrip(uint256 fromSeed, uint256 amountSeed) public {
        address from = _fundedActor(fromSeed);
        address to = from == actors[0] ? actors[1] : actors[0];
        uint256 amount = bound(amountSeed, 1, modelBalance[from]);
        vm.prank(from);
        assertTrue(token.transfer(to, amount));
        // Check the intermediate state too: two broken/no-op transfers must not cancel out.
        assertEq(token.balanceOf(from), modelBalance[from] - amount);
        assertEq(token.balanceOf(to), modelBalance[to] + amount);
        vm.prank(to);
        assertTrue(token.transfer(from, amount));
        assertEq(token.balanceOf(from), modelBalance[from]);
        assertEq(token.balanceOf(to), modelBalance[to]);
    }

    function _approve(address owner, address spender, uint256 amount) private {
        vm.prank(owner);
        assertTrue(token.approve(spender, amount));
        modelAllowance[owner][spender] = amount;
    }

    function _fundedActor(uint256 seed) private view returns (address) {
        // No discarded runs or empty actions: conservation guarantees a funded holder.
        for (uint256 i; i < 4; ++i) {
            address actor = actors[(seed % 4 + i) % 4];
            if (modelBalance[actor] > 0) return actor;
        }
        revert("model lost the entire supply");
    }
}

/// forge-config: default.invariant.runs = 256
/// forge-config: default.invariant.depth = 96
/// forge-config: default.invariant.fail-on-revert = true
contract LaunchTokenInvariantTest is Test {
    LaunchToken private token;
    TokenHandler private handler;

    function setUp() public {
        token = new LaunchToken();
        handler = new TokenHandler(token);
        token.transfer(handler.actors(0), 1_000_000_000 * 10 ** 18);
        bytes4[] memory selectors = new bytes4[](11);
        selectors[0] = TokenHandler.transfer.selector;
        selectors[1] = TokenHandler.approve.selector;
        selectors[2] = TokenHandler.transferFrom.selector;
        selectors[3] = TokenHandler.overdraw.selector;
        selectors[4] = TokenHandler.overdrawWithAllowance.selector;
        selectors[5] = TokenHandler.spendPastAllowance.selector;
        selectors[6] = TokenHandler.rejectZeroRecipient.selector;
        selectors[7] = TokenHandler.rejectZeroSpender.selector;
        selectors[8] = TokenHandler.revokeAndProbe.selector;
        selectors[9] = TokenHandler.spendFullBalance.selector;
        selectors[10] = TokenHandler.roundTrip.selector;
        targetContract(address(handler));
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    function invariant_FixedSupplyAndBalancesMatchIndependentModel() public view {
        uint256 sum;
        for (uint256 i; i < 4; ++i) {
            address actor = handler.actors(i);
            uint256 balance = token.balanceOf(actor);
            assertEq(balance, handler.modelBalance(actor));
            sum += balance;
        }
        assertEq(sum, 1_000_000_000 * 10 ** 18);
        assertEq(token.totalSupply(), sum);
        assertEq(token.balanceOf(address(0)), 0);
        assertEq(token.balanceOf(address(token)), 0);
        assertEq(token.balanceOf(address(this)), 0);
    }

    function invariant_AllAllowancesMatchIndependentModel() public view {
        for (uint256 i; i < 4; ++i) {
            for (uint256 j; j < 4; ++j) {
                address owner = handler.actors(i);
                address spender = handler.actors(j);
                assertEq(token.allowance(owner, spender), handler.modelAllowance(owner, spender));
            }
        }
    }
}
