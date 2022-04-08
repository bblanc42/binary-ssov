// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "solmate/utils/SafeTransferLib.sol";

// contract to create ETH binary SSOV
// Will the price of $ETH be > $3,500 on Friday?
contract Contract is Ownable {
    error EpochEnded();
    error EpochIsOngoing();
    error FailToDeposit();
    error InsufficientAmount();
    error Unauthorized();
    error NothingToWithdraw();

    event BetCreated(Bet bet);
    event Deposited(address indexed depositor, uint256 amount, bool isBullish);
    event Withdraw(address indexed depositor, uint256 amount);

    uint256 private constant DURATION = 7 days;
    uint256 private betCounter = 1;
    uint256 private depositId = 1;
    Status private status;

    enum Status {
        EPOCH_START,
        EPOCH_END
    }

    struct Bet {
        uint256 betId;
        uint256 startTime;
        uint256 assetPrice;
    }

    mapping(uint256 => Bet) bets;
    mapping(address => bool) depositorToIsBullish;
    mapping(address => uint256) depositorToAmount;
    mapping(bool => uint256) isBullishToAmount;
    mapping(uint256 => address) idToDepositor;

    function getAssetPrice() private pure returns (uint256) {
        return 1;
    }

    function createBet() external onlyOwner {
        Bet memory bet = Bet({
            betId: betCounter,
            startTime: block.timestamp,
            assetPrice: getAssetPrice()
        });
        bets[betCounter] = bet;
        betCounter++;
        status = Status.EPOCH_START;
        emit BetCreated(bet);
    }

    function settleEpoch(uint256 betId) external onlyOwner {
        Bet memory bet = bets[betId];

        uint256 currentTime = block.timestamp;
        uint256 startTime = bet.startTime;

        if (startTime + DURATION < currentTime) {
            revert EpochIsOngoing();
        }

        uint256 previousPrice = bet.assetPrice;
        uint256 currentPrice = getAssetPrice();

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

    function deposit(uint256 amount, bool isBullish) external payable {
        if (status == Status.EPOCH_END) {
            revert EpochEnded();
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
        emit Deposited(depositor, amount, isBullish);
    }

    function withdraw() external {
        if (status != Status.EPOCH_END) {
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
