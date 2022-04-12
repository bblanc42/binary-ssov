// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "solmate/utils/SafeTransferLib.sol";
import "./WethPriceFeed.sol";
import {console} from "../utils/Console.sol";

// contract to create ETH binary SSOV
// Will the price of $ETH be > $3,500 on Friday?
contract Contract is Ownable {
    error EpochClosed();
    error EpochIsOngoing();
    error EpochMustHaveStarted();
    error FailToDeposit();
    error InsufficientAmount();
    error Unauthorized();
    error NothingToWithdraw();

    event BetCreated(Bet bet);
    event BetClosed(uint256 betId);
    event Deposit(address indexed depositor, uint256 amount, bool isBullish);
    event Withdraw(address indexed depositor, uint256 amount);

    uint256 private constant DURATION = 7 days;
    uint256 private betCounter = 1;
    uint256 private depositId = 1;
    uint256 private constant MULT_MULTIPLIER = 1_000;

    enum Status {
        EPOCH_START,
        EPOCH_CLOSE,
        EPOCH_END
    }

    struct Bet {
        uint256 betId;
        uint256 startTime;
        uint256 assetPrice;
        Status status;
    }

    mapping(uint256 => Bet) public bets;
    mapping(address => bool) public depositorToIsBullish;
    mapping(address => uint256) public depositorToAmount;
    mapping(bool => uint256) public isBullishToAmount;
    mapping(uint256 => address) public idToDepositor;

    function getAssetPrice(address _priceFeed) private view returns (uint256) {
        uint256 price = WethPriceFeed(_priceFeed).peek();
        return price;
    }

    function createBet(address _priceFeed)
        external
        onlyOwner
        returns (uint256)
    {
        Bet memory bet = Bet({
            betId: betCounter,
            startTime: block.timestamp,
            assetPrice: getAssetPrice(_priceFeed),
            status: Status.EPOCH_START
        });
        bets[betCounter] = bet;
        betCounter++;
        emit BetCreated(bet);
        return bet.betId;
    }

    function settleEpoch(uint256 betId, address _priceFeed) external onlyOwner {
        Bet storage bet = bets[betId];

        uint256 currentTime = block.timestamp;
        uint256 startTime = bet.startTime;

        if (startTime + DURATION > currentTime) {
            revert EpochIsOngoing();
        }

        uint256 previousPrice = bet.assetPrice;
        uint256 currentPrice = getAssetPrice(_priceFeed);

        uint256 bullAmount = isBullishToAmount[true];
        uint256 bearAmount = isBullishToAmount[false];

        if (currentPrice >= previousPrice) {
            for (uint256 i = 1; i < depositId; ++i) {
                address depositor = idToDepositor[i];
                if (!depositorToIsBullish[depositor]) {
                    depositorToAmount[depositor] = 0;
                } else {
                    uint256 previousShare = (depositorToAmount[depositor] *
                        MULT_MULTIPLIER) / bullAmount;
                    depositorToAmount[depositor] +=
                        (previousShare * bearAmount) /
                        MULT_MULTIPLIER;
                }
            }
        } else {
            for (uint256 i = 1; i < depositId; ++i) {
                address depositor = idToDepositor[i];
                // bullish depositor's balance -> 0
                if (depositorToIsBullish[depositor]) {
                    depositorToAmount[depositor] = 0;
                } else {
                    uint256 previousShare = (depositorToAmount[depositor] *
                        MULT_MULTIPLIER) / bearAmount;
                    depositorToAmount[depositor] +=
                        (previousShare * bullAmount) /
                        MULT_MULTIPLIER;
                }
            }
        }
        bet.status = Status.EPOCH_END;
    }

    function closeDeposit(uint256 betId) external onlyOwner {
        Bet storage bet = bets[betId];
        if (bet.status != Status.EPOCH_START) {
            revert EpochMustHaveStarted();
        }
        bet.status = Status.EPOCH_CLOSE;
        emit BetClosed(betId);
    }

    function deposit(uint256 betId, bool isBullish) external payable {
        if (bets[betId].status == Status.EPOCH_CLOSE) {
            revert EpochClosed();
        }
        address depositor = msg.sender;
        uint256 amount = msg.value;
        if (amount < address(depositor).balance) {
            revert InsufficientAmount();
        }
        depositorToIsBullish[depositor] = isBullish;
        depositorToAmount[depositor] += amount;
        isBullishToAmount[isBullish] += amount;
        idToDepositor[depositId] = depositor;
        depositId++;
        (bool success, ) = payable(address(this)).call{value: amount}("");
        if (!success) {
            revert FailToDeposit();
        }
        emit Deposit(depositor, amount, isBullish);
    }

    function withdraw(uint256 betId) external {
        if (bets[betId].status != Status.EPOCH_END) {
            revert EpochIsOngoing();
        }
        address depositor = msg.sender;
        uint256 amount = depositorToAmount[depositor];
        if (amount == 0) {
            revert NothingToWithdraw();
        }
        SafeTransferLib.safeTransferETH(payable(depositor), amount);
        emit Withdraw(depositor, amount);
    }

    receive() external payable {}
}
