// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import {DSTest} from "ds-test/test.sol";
import {Vm} from "forge-std/Vm.sol";
import {Utilities} from "../../utils/Utilities.sol";
import {console} from "../../utils/Console.sol";

import {Contract} from "../Contract.sol";
import {WethPricefeedSimulator} from "../WethPricefeedSimulator.sol";

contract DSTestPlus is DSTest {
    function assertEq(Contract.Status a, Contract.Status b) internal {
        if (a != b) {
            emit log("Error: a == b not satisfied [Contract.Status]");
            fail();
        }
    }
}

contract ContractTest is DSTestPlus {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);
    uint256 internal WETH_BEAR_PRICE = 2_000 * 10**18; // ETH/USD 2,000.000
    uint256 internal WETH_START_PRICE = 3_000 * 10**18; // ETH/USD 3,000.000
    uint256 internal WETH_BULL_PRICE = 4_000 * 10**18; // ETH/USD 4,000.000
    Utilities internal utils;

    address payable[] internal users;
    address payable internal alice;
    address payable internal bob;
    address payable internal charlie;
    uint256 betIdOne = 1;

    Contract internal binarySsov;
    WethPricefeedSimulator internal wethPricefeedSimulator;

    function setUp() public {
        utils = new Utilities();
        users = utils.createUsers(3);

        alice = users[0];
        bob = users[1];
        charlie = users[2];

        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(charlie, "Charlie");

        // everyone starts with 10 eth
        for (uint256 i; i < 3; i++) {
            vm.deal(users[i], 10 ether);
            assertEq(address(users[i]).balance, 10 ether);
        }

        wethPricefeedSimulator = new WethPricefeedSimulator(WETH_START_PRICE);
        vm.label(address(binarySsov), "WETH simulator");
        binarySsov = new Contract();
        vm.label(address(binarySsov), "Binary SSOV");
        binarySsov.createBet(address(wethPricefeedSimulator));
    }

    function testCreateBet() public {
        uint256 betId = binarySsov.createBet(address(wethPricefeedSimulator));
        assertEq(betId, 2);
        (, , uint256 assetPrice, ) = binarySsov.bets(2);
        assertEq(assetPrice, WETH_START_PRICE);
    }

    function testFailNonOwnerSettleOngoingEpoch() public {
        vm.prank(alice);
        binarySsov.settleEpoch(betIdOne, address(wethPricefeedSimulator));
    }

    function testCannotSettleOngoingEpoch() public {
        vm.warp(5 days);
        vm.expectRevert(abi.encodeWithSignature("EpochIsOngoing()"));
        binarySsov.settleEpoch(betIdOne, address(wethPricefeedSimulator));
    }

    function testSettleEndedEpoch() public {
        binarySsov.closeDeposit(betIdOne);
        (, , , Contract.Status status) = binarySsov.bets(betIdOne);
        assertEq(status, Contract.Status.EPOCH_CLOSE);
        vm.warp(7 days + 1);
        binarySsov.settleEpoch(betIdOne, address(wethPricefeedSimulator));
        (, , , status) = binarySsov.bets(betIdOne);
        assertEq(status, Contract.Status.EPOCH_END);
    }

    function testFailDepositAfterClose() public {
        binarySsov.closeDeposit(betIdOne);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("EpochMustHaveStarted()"));
        binarySsov.deposit(betIdOne, true);
    }

    function testFailDepositInsufficientAmount() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("InsufficientAmount()"));
        binarySsov.deposit{value: 100 ether}(betIdOne, true);
    }

    function testDepositBull() public {
        vm.prank(alice);
        binarySsov.deposit{value: 5 ether}(betIdOne, true);
        binarySsov.closeDeposit(betIdOne);
        assertEq(binarySsov.isBullishToAmount(true), 5 ether);
        assertEq(binarySsov.depositorToAmount(address(alice)), 5 ether);
        assert(binarySsov.depositorToIsBullish(address(alice)));
        assertEq(binarySsov.isBullishToAmount(false), 0);
        assertEq(address(binarySsov).balance, 5 ether);
    }

    function testDepositBear() public {
        vm.prank(alice);
        binarySsov.deposit{value: 5 ether}(betIdOne, false);
        binarySsov.closeDeposit(betIdOne);
        assertEq(binarySsov.isBullishToAmount(false), 5 ether);
        assertEq(binarySsov.depositorToAmount(address(alice)), 5 ether);
        assert(!binarySsov.depositorToIsBullish(address(alice)));
        assertEq(binarySsov.isBullishToAmount(true), 0);
        assertEq(address(binarySsov).balance, 5 ether);
    }

    function testWithdrawSetup() public {
        vm.prank(alice);
        binarySsov.deposit{value: 5 ether}(betIdOne, true);
        vm.prank(bob);
        binarySsov.deposit{value: 5 ether}(betIdOne, false);
        vm.prank(charlie);
        binarySsov.deposit{value: 5 ether}(betIdOne, false);
        binarySsov.closeDeposit(betIdOne);
        assertEq(binarySsov.isBullishToAmount(true), 5 ether);
        assertEq(binarySsov.isBullishToAmount(false), 10 ether);
        assert(binarySsov.depositorToIsBullish(address(alice)));
        assert(!binarySsov.depositorToIsBullish(address(bob)));
        assert(!binarySsov.depositorToIsBullish(address(charlie)));
        assertEq(binarySsov.depositorToAmount(address(alice)), 5 ether);
        assertEq(binarySsov.depositorToAmount(address(bob)), 5 ether);
        assertEq(binarySsov.depositorToAmount(address(charlie)), 5 ether);
        assertEq(address(binarySsov).balance, 15 ether);
        vm.warp(7 days + 1);
    }

    function testWinnerWithdraw() public {
        testWithdrawSetup();
        wethPricefeedSimulator.setValue(WETH_BULL_PRICE);
        binarySsov.settleEpoch(betIdOne, address(wethPricefeedSimulator));
        assertEq(binarySsov.depositorToAmount(address(alice)), 15 ether);
        assertEq(binarySsov.depositorToAmount(address(bob)), 0 ether);
        assertEq(binarySsov.depositorToAmount(address(charlie)), 0 ether);
        (, , , Contract.Status status) = binarySsov.bets(betIdOne);
        assertEq(status, Contract.Status.EPOCH_END);
        assertEq(address(alice).balance, 5 ether);
        vm.prank(alice);
        binarySsov.withdraw(betIdOne);
        assertEq(address(alice).balance, 20 ether);
    }

    function testLoserWithdraw() public {
        testWithdrawSetup();
        wethPricefeedSimulator.setValue(WETH_BEAR_PRICE);
        binarySsov.settleEpoch(betIdOne, address(wethPricefeedSimulator));
        assertEq(binarySsov.depositorToAmount(address(alice)), 0);
        assertEq(binarySsov.depositorToAmount(address(bob)), 7.5 ether);
        assertEq(binarySsov.depositorToAmount(address(charlie)), 7.5 ether);
        (, , , Contract.Status status) = binarySsov.bets(betIdOne);
        assertEq(status, Contract.Status.EPOCH_END);
        assertEq(address(bob).balance, 5 ether);
        vm.prank(bob);
        binarySsov.withdraw(betIdOne);
        assertEq(address(bob).balance, 12.5 ether);
    }

    function testCannotWithdraw() public {
        vm.prank(alice);
        binarySsov.deposit{value: 5 ether}(betIdOne, true);
        vm.prank(bob);
        binarySsov.deposit{value: 5 ether}(betIdOne, false);
        vm.prank(charlie);
        binarySsov.deposit{value: 5 ether}(betIdOne, false);
        binarySsov.closeDeposit(betIdOne);
        assertEq(address(alice).balance, 5 ether);
        vm.expectRevert(abi.encodeWithSignature("EpochIsOngoing()"));
        vm.prank(alice);
        binarySsov.withdraw(betIdOne);
        assertEq(address(alice).balance, 5 ether);
    }

    function testContract() public {
        assertTrue(false);
    }
}
