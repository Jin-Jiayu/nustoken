// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.5.0;

/** 
 * @title NUSElections
 */

 /** 
 * To-do:
 * 1. Use NUSToken once NUSToken contract is ready
 * 2. Events 
 */

contract NUSElections {

    struct Voter {
        uint256 weight; // weight is accumulated by delegation, default is 0
        bool voted;  // if true, that person already voted, default is false 
        // address delegate; // person delegated to
        uint256 vote;   // index of the voted proposal, default is 0
    }

    // NUSToken nusTokenInstance
    address public electionOwner;
    address[] voterList;
    uint256[] votingOptions;
    uint256[] votingResultsList;
    mapping(address => Voter) voters;
    mapping(uint256 => uint256) votingResults;
    bool electionStatus;
    uint256 totalVotes = 0;

    /** 
     * Create a new election
     * @param options a list of options, always start from index 0. (frontend need to configure it to start from 0)
     */
    constructor(uint256[] memory options) public {
        electionOwner = msg.sender;
        votingOptions = options;
        electionStatus = false;
        votingResultsList = new uint256[](options.length);
    }

    // events 
    
    // A event that emits the id of the winning vote and the vote count when there is only 1 winner 
    event winningVote(uint256, uint256);
    // A event that emits the vote count when the voting results in a draw
    event draw(uint256);
    // A event that emits the ids of the voting options that result in a draw
    event drawVotes(uint256);
    // A event that emit that no one has voted 
    event  noOneVoted();

    // modifiers 

    modifier electionOngoing() {
        require(
            !electionStatus, 
            "Election has ended."
        );
        _;
    }

    modifier electionEnded() {
        require(
            electionStatus, 
            "Election not ended yet."
        );
        _;
    }

    // when doing frontend, map the options of the voting to a index, starting from 0
    modifier validVotingChoice(uint256 votingChoice) {
        require(
            votingChoice >= 0 && votingChoice <= votingOptions.length, 
            "Invalid voting option"
        );
        _;
    }

    // main functions 

    /**
    * Function to allow user to vote, voting weightage will be based on the NUST
    * As long as the election is ongoing, the user can change their vote by revoting.
    * @param votingChoice uint256, which must be in range of the votingOptions
    **/
    function vote(uint256 votingChoice) electionOngoing validVotingChoice(votingChoice) public {
        // uint256 memory curr_voter_NUST = nusTokenInstance.checkCredit();
        uint256 curr_voter_NUST = 1;
        Voter memory curr_voter = Voter(curr_voter_NUST, true, votingChoice);
        if (voters[msg.sender].voted == false) { // voter has not voted before 
            voters[msg.sender] = curr_voter;
            voterList.push(msg.sender);
            totalVotes += curr_voter_NUST;
        } else { // voter has voted before, voter is changing vote 
            voters[msg.sender] = curr_voter;
        }
    }

    /**
    * Function to tally vote, once the tally of vote is completed, the election has ended. 
    * This function will update votingResults and votingResultsList
    **/
    function tallyVote() public electionOngoing {
        // count the votes 
        for (uint256 i=0; i<voterList.length; i++) {
            Voter memory curr_voter = voters[voterList[i]];
            votingResults[curr_voter.vote] += curr_voter.weight;
        }

        // store result in a array 
        for (uint i = 0; i < votingOptions.length; i++) {
            votingResultsList[i] = votingResults[i];
        }

        // end election
        electionStatus = true;

    }

    /**
    * Function to get the voting result after the tally of the vote is completed. 
    **/

    function getVotingResult() public electionEnded returns(uint256[] memory) {
        // find the max vote as the winner vote 
        uint256 maxVoteCount = 0;
        uint256 totalNumberWinningVote = 0; // to keep track if there is a draw 
        for (uint256 i=0; i<votingResultsList.length; i++) {
            if (votingResultsList[i] == 0) {
                // if vote count for this option is 0, just skip 
                continue;
            }
            else if (votingResultsList[i] > maxVoteCount) {
                maxVoteCount = votingResultsList[i];
                totalNumberWinningVote = 1;
            } else if (votingResultsList[i] == maxVoteCount) { // draw 
                totalNumberWinningVote += 1;
            } 
        }

        if (totalNumberWinningVote == 0) {
            // means no one voted at all 
            // maybe should put a modifier for tallyVote() to ensure there is at least a certain amount of people that voted before closing the voting
            emit noOneVoted();
        } else if (totalNumberWinningVote == 1) {
            // there is only 1 winning vote 
            for (uint256 i=0; i<votingResultsList.length; i++) {
                if (votingResultsList[i] == maxVoteCount) {
                    emit winningVote(i, votingResultsList[i]);
                    break;
                }
            }
        } else { 
            // there is multple wining option / draw 
            emit draw(maxVoteCount);
            for (uint256 i=0; i<votingResultsList.length; i++) {
                if (votingResultsList[i] == maxVoteCount) {
                    emit drawVotes(i);
                }
            }

        }

        return votingResultsList;

        // ignore this part first 
        // uint256 majority = (totalVotes - 1) / votingOptions.length + 1;
        // uint256 winningVoteCount = 0;
        // bool[] memory winningTracker = new bool[](votingOptions.length); // true for winning vote, default to false
        // // majority winner 
        // for (uint256 i=0; i<votingResultsList.length; i++) {
        //     if (votingResultsList[i] >= majority) {
        //         winningTracker[i] = true;
        //         winningVoteCount += 1;
        //     }
        // }

        // if (totalVotes < votingOptions.length) {
        //     // cannot do majority for this case 

        //     return votingResultsList;
        // }

        // if (winningVoteCount == 0) {
        //     emit noWinningVote();
        // } else if (winningVoteCount == 1) {  // 1 majority winning vote
        //     for (uint256 i=0; i<winningTracker.length; i++) {
        //         if (winningTracker[i]) {
        //             emit winningVote(i);
        //             break;
        //         }
        //     }
        // } else { // multiple winning vote / draw 
        //     emit draw();
        //     for (uint256 i=0; i<winningTracker.length; i++) {
        //         if (winningTracker[i]) {
        //             emit multpleWinningVote(i);
        //         }
        //     }
        // }
        
    }

    // getters and helpers 
    function getVotingChoice() public view returns(uint256) {
        return voters[msg.sender].vote;
    }

    function getTotalVotes() public view returns(uint256) {
        return totalVotes;
    }

    function test(uint a, uint b) public public returns(uint) {
        uint x = (a - 1) / b + 1;
        return x;
    }

}
