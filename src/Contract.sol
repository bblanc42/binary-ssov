// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "solmate/utils/SafeTransferLib.sol";
import "./WethPriceFeed.sol";

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
    Status public status;

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

    mapping(uint256 => Bet) private bets;
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
            assetPrice: getAssetPrice(_priceFeed)
        });
        bets[betCounter] = bet;
        betCounter++;
        status = Status.EPOCH_START;
        emit BetCreated(bet);
        return bet.betId;
    }

    // memory or calldata?
    function getBet(uint256 betId) external view returns (Bet memory) {
        return bets[betId];
    }

    function settleEpoch(uint256 betId, address _priceFeed) external onlyOwner {
        Bet memory bet = bets[betId];

        uint256 currentTime = block.timestamp;
        uint256 startTime = bet.startTime;

        if (startTime + DURATION > currentTime) {
            revert EpochIsOngoing();
        }

        uint256 previousPrice = bet.assetPrice;
        uint256 currentPrice = getAssetPrice(_priceFeed);

        uint256 bearAmount = isBullishToAmount[false];
        uint256 bullAmount = isBullishToAmount[true];

        if (currentPrice >= previousPrice) {
            for (uint256 i = 0; i < depositId; ++i) {
                address depositor = idToDepositor[i];
                if (!depositorToIsBullish[depositor]) {
                    depositorToAmount[depositor] = 0;
                } else {
                    uint256 previousShare = depositorToAmount[depositor] /
                        bullAmount;
                    depositorToAmount[depositor] += previousShare * bearAmount;
                }
            }
        } else {
            for (uint256 i = 0; i < depositId; ++i) {
                address depositor = idToDepositor[i];
                if (depositorToIsBullish[depositor]) {
                    depositorToAmount[depositor] = 0;
                } else {
                    uint256 previousShare = depositorToAmount[depositor] /
                        bearAmount;
                    depositorToAmount[depositor] += previousShare * bearAmount;
                }
            }
        }
        status = Status.EPOCH_END;
    }

    function closeDeposit(uint256 betId) external onlyOwner {
        if (status != Status.EPOCH_START) {
            revert EpochMustHaveStarted();
        }
        Bet memory bet = bets[betId];
        bet.status = Status.EPOCH_CLOSE;
        emit BetClosed(betId);
    }

    function deposit(
        uint256 betId,
        uint256 amount,
        bool isBullish
    ) external payable {
        if (bets[betId].status == Status.EPOCH_CLOSE) {
            revert EpochClosed();
        }
        address depositor = msg.sender;
        if (msg.value < amount) {
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
