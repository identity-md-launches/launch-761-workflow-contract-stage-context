// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {LaunchToken} from "src/LaunchToken.sol";

/// @notice Additional authorization and arithmetic boundaries for the approved NODEV token.
/// forge-config: default.fuzz.runs = 1000
contract LaunchTokenAdversarialTest is Test {
    uint256 private constant SUPPLY = 1e27;
    address private constant HOLDER = address(0xA11CE);
    address private constant RECEIVER = address(0xB0B);
    address private constant SPENDER = address(0x5EED);
    address private constant OTHER = address(0xCAFE);
    LaunchToken private token;

    function setUp() public {
        token = new LaunchToken();
        assertTrue(token.transfer(HOLDER, SUPPLY));
    }

    function test_MaxMinusOneAllowanceIsFiniteAcrossRepeatedSpends() public {
        _approve(HOLDER, SPENDER, type(uint256).max - 1);
        vm.startPrank(SPENDER);
        assertTrue(token.transferFrom(HOLDER, RECEIVER, 1));
        assertTrue(token.transferFrom(HOLDER, RECEIVER, SUPPLY - 1));
        vm.stopPrank();
        assertEq(token.allowance(HOLDER, SPENDER), type(uint256).max - 1 - SUPPLY);
        _assertBalances(0, SUPPLY, 0, 0);
    }

    function test_DelegatedSelfTransferCannotBypassBalanceCheck() public {
        _approve(HOLDER, SPENDER, SUPPLY + 1);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, HOLDER, SUPPLY, SUPPLY + 1)
        );
        vm.prank(SPENDER);
        token.transferFrom(HOLDER, HOLDER, SUPPLY + 1);
        assertEq(token.allowance(HOLDER, SPENDER), SUPPLY + 1);
        _assertBalances(SUPPLY, 0, 0, 0);
    }

    function test_RevocationIsIdempotentAndIsolatedBetweenSpenders() public {
        _approve(HOLDER, SPENDER, type(uint256).max);
        _approve(HOLDER, OTHER, 7);
        vm.prank(SPENDER);
        assertTrue(token.transferFrom(HOLDER, RECEIVER, 3));
        _approve(HOLDER, SPENDER, 0);
        _approve(HOLDER, SPENDER, 0);
        _expectAllowanceFailure(SPENDER, HOLDER, RECEIVER, 0, 1);
        assertEq(token.allowance(HOLDER, OTHER), 7);
        vm.prank(OTHER);
        assertTrue(token.transferFrom(HOLDER, RECEIVER, 7));
        _expectAllowanceFailure(OTHER, HOLDER, RECEIVER, 0, 1);
        assertEq(token.allowance(HOLDER, SPENDER), 0);
        assertEq(token.allowance(HOLDER, OTHER), 0);
        _assertBalances(SUPPLY - 10, 10, 0, 0);
    }

    function test_ApprovalsDoNotTransitivelyDelegateAuthority() public {
        _approve(HOLDER, SPENDER, 7);
        _approve(SPENDER, OTHER, 7);
        _expectAllowanceFailure(OTHER, HOLDER, OTHER, 0, 1);
        assertEq(token.allowance(HOLDER, SPENDER), 7);
        assertEq(token.allowance(SPENDER, OTHER), 7);
        _assertBalances(SUPPLY, 0, 0, 0);

        // OTHER can spend SPENDER's tokens only after SPENDER actually owns them.
        vm.prank(SPENDER);
        assertTrue(token.transferFrom(HOLDER, SPENDER, 7));
        vm.prank(OTHER);
        assertTrue(token.transferFrom(SPENDER, RECEIVER, 7));
        assertEq(token.allowance(HOLDER, SPENDER), 0);
        assertEq(token.allowance(SPENDER, OTHER), 0);
        _assertBalances(SUPPLY - 7, 7, 0, 0);
    }

    function test_ZeroDelegatedTransferToZeroStillReverts() public {
        _approve(HOLDER, SPENDER, 7);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        vm.prank(SPENDER);
        token.transferFrom(HOLDER, address(0), 0);
        assertEq(token.allowance(HOLDER, SPENDER), 7);
        _assertBalances(SUPPLY, 0, 0, 0);
    }

    function test_KnownMutatorsRejectEtherWithoutChangingTokenState() public {
        _approve(HOLDER, HOLDER, 1);
        vm.deal(HOLDER, 3);
        bytes[3] memory calls = [
            abi.encodeCall(token.transfer, (RECEIVER, 1)),
            abi.encodeCall(token.approve, (SPENDER, 7)),
            abi.encodeCall(token.transferFrom, (HOLDER, RECEIVER, 1))
        ];
        for (uint256 i; i < calls.length; ++i) {
            vm.prank(HOLDER);
            (bool success,) = address(token).call{value: 1}(calls[i]);
            assertFalse(success, "ERC20 mutator accepted ETH");
            _assertBalances(SUPPLY, 0, 0, 0);
            assertEq(token.allowance(HOLDER, HOLDER), 1);
            assertEq(token.allowance(HOLDER, SPENDER), 0);
            assertEq(HOLDER.balance, 3);
            assertEq(address(token).balance, 0);
        }
    }

    function testFuzz_PartialSpendsCannotReuseExhaustedBudget(uint256 approvalSeed, uint256 splitSeed) public {
        uint256 approved = bound(approvalSeed, 1, SUPPLY);
        uint256 first = bound(splitSeed, 0, approved);
        uint256 second = approved - first;
        _approve(HOLDER, SPENDER, approved);
        vm.prank(SPENDER);
        assertTrue(token.transferFrom(HOLDER, RECEIVER, first));
        assertEq(token.allowance(HOLDER, SPENDER), second);
        _assertBalances(SUPPLY - first, first, 0, 0);
        vm.prank(SPENDER);
        assertTrue(token.transferFrom(HOLDER, OTHER, second));
        _expectAllowanceFailure(SPENDER, HOLDER, RECEIVER, 0, 1);
        assertEq(token.allowance(HOLDER, SPENDER), 0);
        _assertBalances(SUPPLY - approved, first, 0, second);
    }

    function testFuzz_ReducedAllowanceReplacesRemainingBudget(uint256 spentSeed, uint256 reducedSeed) public {
        uint256 spent = bound(spentSeed, 0, SUPPLY - 1);
        uint256 reduced = bound(reducedSeed, 0, SUPPLY - spent - 1);
        _approve(HOLDER, SPENDER, type(uint256).max);
        vm.prank(SPENDER);
        assertTrue(token.transferFrom(HOLDER, RECEIVER, spent));
        assertEq(token.allowance(HOLDER, SPENDER), type(uint256).max);
        _approve(HOLDER, SPENDER, reduced);
        _expectAllowanceFailure(SPENDER, HOLDER, RECEIVER, reduced, reduced + 1);
        assertEq(token.allowance(HOLDER, SPENDER), reduced);
        _assertBalances(SUPPLY - spent, spent, 0, 0);
        vm.prank(SPENDER);
        assertTrue(token.transferFrom(HOLDER, RECEIVER, reduced));
        assertEq(token.allowance(HOLDER, SPENDER), 0);
        _assertBalances(SUPPLY - spent - reduced, spent + reduced, 0, 0);
    }

    function testFuzz_FailedSpendPreservesApprovalForLaterFunding(uint256 balanceSeed, uint256 amountSeed) public {
        uint256 balance = bound(balanceSeed, 0, SUPPLY - 1);
        uint256 amount = bound(amountSeed, balance + 1, SUPPLY);
        vm.prank(HOLDER);
        assertTrue(token.transfer(RECEIVER, balance));
        _approve(RECEIVER, SPENDER, amount);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, RECEIVER, balance, amount)
        );
        vm.prank(SPENDER);
        token.transferFrom(RECEIVER, OTHER, amount);
        assertEq(token.allowance(RECEIVER, SPENDER), amount);
        _assertBalances(SUPPLY - balance, balance, 0, 0);

        vm.prank(HOLDER);
        assertTrue(token.transfer(RECEIVER, amount - balance));
        vm.prank(SPENDER);
        assertTrue(token.transferFrom(RECEIVER, OTHER, amount));
        assertEq(token.allowance(RECEIVER, SPENDER), 0);
        _assertBalances(SUPPLY - amount, 0, 0, amount);
    }

    function testFuzz_HighFiniteAllowanceDecreasesExactly(uint256 approvalSeed, uint256 amountSeed) public {
        uint256 approved = bound(approvalSeed, SUPPLY + 1, type(uint256).max - 1);
        uint256 amount = bound(amountSeed, 1, SUPPLY);
        _approve(HOLDER, SPENDER, approved);
        vm.prank(SPENDER);
        assertTrue(token.transferFrom(HOLDER, RECEIVER, amount));
        assertEq(token.allowance(HOLDER, SPENDER), approved - amount);
        _assertBalances(SUPPLY - amount, amount, 0, 0);
    }

    function testFuzz_SelfApprovalStillRequiresBudget(uint256 approvalSeed, uint256 amountSeed) public {
        uint256 approved = bound(approvalSeed, 0, SUPPLY - 1);
        uint256 amount = bound(amountSeed, approved + 1, SUPPLY);
        _approve(HOLDER, HOLDER, approved);
        _expectAllowanceFailure(HOLDER, HOLDER, RECEIVER, approved, amount);
        assertEq(token.allowance(HOLDER, HOLDER), approved);
        _assertBalances(SUPPLY, 0, 0, 0);
    }

    function _approve(address owner, address spender, uint256 amount) private {
        vm.prank(owner);
        assertTrue(token.approve(spender, amount));
    }

    function _expectAllowanceFailure(address caller, address from, address to, uint256 approved, uint256 amount)
        private
    {
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, caller, approved, amount)
        );
        vm.prank(caller);
        token.transferFrom(from, to, amount);
    }

    function _assertBalances(
        uint256 holderBalance,
        uint256 receiverBalance,
        uint256 spenderBalance,
        uint256 otherBalance
    ) private view {
        assertEq(token.balanceOf(HOLDER), holderBalance);
        assertEq(token.balanceOf(RECEIVER), receiverBalance);
        assertEq(token.balanceOf(SPENDER), spenderBalance);
        assertEq(token.balanceOf(OTHER), otherBalance);
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.balanceOf(address(0)), 0);
        assertEq(token.balanceOf(address(token)), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }
}
