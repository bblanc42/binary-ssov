// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "abdk-libraries-solidity/ABDKMath64x64.sol";
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
    event EpochSettle();

    uint256 private constant DURATION = 7 days;
    uint256 private betCounter = 1;
    uint256 private depositId = 1;
    uint256 public bullsAmount = 0;
    uint256 public bearsAmount = 0;

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
    mapping(address => bool) public depositors;
    mapping(uint256 => address) public idToDepositor;
    mapping(address => uint256) public depositorToAmount;

    function getAssetPrice(address _priceFeed) private view returns (uint256) {
        uint256 price = WethPriceFeed(_priceFeed).peek();
        return price;
    }

    function rollover() private {
        for (uint256 i = 1; i < depositId; ++i) {
            address depositor = idToDepositor[i];
            uint256 amount = depositorToAmount[depositor];
            if (amount != 0) {
                if (depositorToIsBullish[depositor]) {
                    bullsAmount += amount;
                } else {
                    bearsAmount += amount;
                }
            }
        }
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
        rollover();
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

        if (currentPrice >= previousPrice) {
            for (uint256 i = 1; i < depositId; ++i) {
                address depositor = idToDepositor[i];
                uint256 amount = depositorToAmount[depositor];
                if (amount == 0) {
                    continue;
                }

                if (!depositorToIsBullish[depositor]) {
                    depositorToAmount[depositor] = 0;
                } else {
                    int128 previousShare = ABDKMath64x64.divu(
                        amount,
                        bullsAmount
                    );
                    depositorToAmount[depositor] += ABDKMath64x64.mulu(
                        previousShare,
                        bearsAmount
                    );
                }
            }
        } else {
            for (uint256 i = 1; i < depositId; ++i) {
                address depositor = idToDepositor[i];
                uint256 amount = depositorToAmount[depositor];
                if (amount == 0) {
                    continue;
                }

                // bullish depositor's balance -> 0
                if (depositorToIsBullish[depositor]) {
                    depositorToAmount[depositor] = 0;
                } else {
                    int128 previousShare = ABDKMath64x64.divu(
                        amount,
                        bearsAmount
                    );
                    depositorToAmount[depositor] += ABDKMath64x64.mulu(
                        previousShare,
                        bullsAmount
                    );
                }
            }
        }
        bullsAmount = 0;
        bearsAmount = 0;
        bet.status = Status.EPOCH_END;
        emit EpochSettle();
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

        depositorToIsBullish[depositor] = isBullish;
        depositorToAmount[depositor] += amount;

        if (isBullish) {
            bullsAmount += amount;
        } else {
            bearsAmount += amount;
        }

        // add new depositor to `depositors`
        if (!depositors[depositor]) {
            depositors[depositor] = true;
            idToDepositor[depositId] = depositor;
            depositId++;
        }

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

        depositorToAmount[depositor] = 0;

        SafeTransferLib.safeTransferETH(payable(depositor), amount);
        emit Withdraw(depositor, amount);
    }

    receive() external payable {}
}
