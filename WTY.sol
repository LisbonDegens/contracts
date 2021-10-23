// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.6.12;

import {ILendingPool} from "@aave/protocol-v2/contracts/interfaces/ILendingPool.sol";
import {IERC20} from "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.1.0/contracts/token/ERC20/IERC20.sol";

/**
 * @title WinnerTakesYield
 */
contract WinnerTakesYield {
    struct League {
        address token;
        address pool;
        uint256 endTime;
        uint256 pot;
        bool winnerAwarded;
        mapping(address => uint256) stakes;
    }

    League[] public leagues;

    /**
     * @dev Create tournament
     */
    function createLeague(
        address _token,
        address _pool,
        uint256 _endTime
    ) public {
        leagues.push(League(_token, _pool, 0, _endTime, false));
    }

    /**
     * @dev Add to pool
     */
    function deposit(uint256 leagueIndex, uint256 amount) public {
        League storage league = leagues[leagueIndex];

        // Increase the users stake
        league.stakes[msg.sender] += amount;
        // Increase the total pot
        league.pot += amount;

        // Transfer the users tokens to us
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
    }

    /**
     * @dev End league
     */
    function awardWinner(uint256 leagueIndex, address winner) public {
        League storage league = leagues[leagueIndex];

        require(block.timestamp >= league.endTime, "League time is not over");
        require(!league.winnerAwarded, "Winner has not been awarded yet");

        // Finish the league
        league.winnerAwarded = true;

        // Withdraw all the tokens from AAVE to WTY
        ILendingPool(league.pool).withdraw(
            league.token,
            type(uint256).max,
            address(this)
        );

        // Calculate the yield based on the current WTY balance vs the original pot
        uint256 yield = IERC20(league.token).balanceOf(address(this)) -
            league.pot;

        // Transfer the yield from WTY to the winner
        IERC20(league.token).transfer(winner, yield);
    }

    /**
     * @dev Withdraw
     */
    function withdraw(uint256 leagueIndex) public {
        League storage league = leagues[leagueIndex];

        uint256 stake = league.stakes[msg.sender];
        // Set the users stake to zero
        league.stakes[msg.sender] = 0;

        // Transfer the user their tokens back
        IERC20(league.token).transfer(msg.sender, stake);
    }
}
