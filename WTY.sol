pragma solidity >=0.6.12;

import {ILendingPool} from "@aave/protocol-v2/contracts/interfaces/ILendingPool.sol";
import {IERC20} from "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.1.0/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.1.0/contracts/access/Ownable.sol";

/**
 * @title WinnerTakesYield
 */
contract WinnerTakesYield is Ownable {
    struct League {
        address token;
        address aToken;
        address pool;
        address winner;
        uint256 totalStake;
        mapping(address => uint256) stakes;
    }

    event Deposit(uint256, uint256);
    event WinnerSet(uint256, address);
    event AwardRedeemed(address, uint256, uint256);
    event Withdraw(uint256, uint256);

    League[] public leagues;

    /**
     * @dev Create league
     */
    function createLeague(
        address _token,
        address _aToken,
        address _pool
    ) public {
        leagues.push(League(_token, _aToken, _pool, address(0), 0));
    }

    /**
     * @dev Add to pool
     */
    function deposit(uint256 leagueIndex, uint256 amount) public {
        League storage league = leagues[leagueIndex];

        // Transfer the users added stake to us
        IERC20(league.token).transferFrom(msg.sender, address(this), amount);

        // Approve the token transfer from WTY to AAVE
        IERC20(league.token).approve(league.pool, amount);

        // Deposit the tokens from WTY to AAVE
        ILendingPool(league.pool).deposit(
            league.token,
            amount,
            address(this),
            0
        );

        // Track the amount the sender contributed
        league.stakes[msg.sender] += amount;
        league.totalStake += amount;

        emit Deposit(leagueIndex, amount);
    }

    /**
     * @dev Withdraw
     */
    function withdraw(uint256 leagueIndex) public {
        League storage league = leagues[leagueIndex];

        uint256 stake = league.stakes[msg.sender];

        // Track the removed stake
        league.stakes[msg.sender] = 0;
        league.totalStake -= stake;

        // Remove the users original stake from AAVE
        ILendingPool(league.pool).withdraw(league.token, stake, msg.sender);

        emit Withdraw(leagueIndex, stake);
    }

    function setWinner(uint256 leagueIndex, address winner) public onlyOwner {
        League storage league = leagues[leagueIndex];

        league.winner = winner;

        emit WinnerSet(leagueIndex, league.winner);
    }

    /**
     * @dev Redeem award
     */
    function redeemAward(uint256 leagueIndex) public {
        League storage league = leagues[leagueIndex];

        require(league.winner != address(0), "Winner has not been set yet");

        uint256 reward = IERC20(league.aToken).balanceOf(address(this)) -
            league.totalStake;

        // Redeem all aTokens the contract owns for the sender, minus the supply reserved for donators
        ILendingPool(league.pool).withdraw(league.token, reward, league.winner);

        emit AwardRedeemed(league.winner, leagueIndex, reward);
    }

    function getTotalStake(uint256 leagueIndex) public view returns (uint256) {
        return leagues[leagueIndex].totalStake;
    }
}
