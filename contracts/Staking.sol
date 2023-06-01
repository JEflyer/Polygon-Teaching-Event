//SPDX-License-Identifier:GLWTPL
pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ICoin is IERC20 {
    function Mint(address to, uint256 amount) external returns(bool);
}

contract Staking {
    
    struct StepInfo {
        uint256 treasury;
        uint256 totalNFTsStaked;
        uint256 totalRewardThisStep;
        uint256 timeStepStarted;
        uint256 timeStepEnded;
    }

    //TokenID => StepID
    mapping(uint256 => uint256) private stepStaked;

    mapping(uint256 => StepInfo) private stepInfo;

    uint256 public latestStepID;

    mapping(address => uint256[]) private NFTsStakedByUser;

    IERC721 private NFTMinter;
    ICoin private token;

    uint256 public timeLastUpdated;

    constructor(
        uint256 initialTreasury,
        address _token,
        address minter
    ){
        require(initialTreasury != 0,"ERR:NN");//NN => Null Number
        require(_token != address(0),"ERR:NA");//NA => Null Address
        require(minter != address(0),"ERR:NA2");//NA2 => Null Address 2

        NFTMinter = IERC721(minter);
        token = IERC20(_token);
        stepInfo[1].treasury = initialTreasury;
    }

    function stake(uint256 tokenId) external {
        //Check that the caller owns the NFT
        require(NFTMinter.ownerOf(tokenId) == msg.sender,"ERR:NO");//NO => Not Owner

        //Check that the caller has approved this contract to spend that NFT
        require(NFTMinter.getApproved(tokenId) == address(this),"ERR:NA");//NA => Not Approved
    
        //Get current step ID
        uint256 currentStepID = latestStepID;

        //Check that the current step did not start this second - This is actually a security check to make sure a contact is not staking & unstaking to cause multiple steps to occur during the same second
        require(stepInfo[currentStepID].timeStepStarted < block.timestamp,"ERR:TS");//TS => Too Soon 

        //Transfer the token to this contract
        NFTMinter.transferFrom(msg.sender,address(this),tokenId);

        //Get next step ID
        uint256 nextStepID = currentStepID + 1;

        // Save the step the NFT was staked on as the next step ID
        stepStaked[tokenId] = nextStepID;

        //Add the tokenID to the array that the user has staked on
        NFTsStakedByUser[msg.sender].push(tokenId);

        //Call Update step
        updateStep(stepInfo[currentStepID].totalNFTsStaked + 1);
    
        //Emit event
    
    }

    function unstake(uint256 tokenId) external {
        //Check that the NFT has been staked
        require(stepStaked[tokenId] > 0,"ERR:NS");//NS => Not Staked

        //Check that the current step did not start this second - This is actually a security check to make sure a contact is not staking & unstaking to cause multiple steps to occur during the same second
        require(stepInfo[currentStepID].timeStepStarted < block.timestamp,"ERR:TS");//TS => Too Soon 

        //Check that the caller is the one that staked the NFT
        bool check = false;
        uint256 index = 0;
        uint256[] memory stakedNFTs = NFTsStakedByUser[msg.sender];
        for(uint256 i = 0; i < stakedNFTs.length;){

            if(stakedNFTs[i] == tokenId){
                check = true;
                index = i;
                break;
            }

            unchecked{
                i++;
            }
        }
        require(check,"ERR:DS");//DS => Didn't Stake

        //Calculate the due reward for the user
        uint256 reward = getDueReward(tokenId);

        //Transfer the NFT back to the staker
        NFTMinter.transferFrom(address(this),msg.sender,tokenId);

        //Remove the NFT from the users staked token list
        if(stakedNFTs.length == 1){
            delete NFTsStakedByUser[msg.sender];
        }else {
            delete NFTsStakedByUser[msg.sender][index];
            NFTsStakedByUser[msg.sender][index] = stakedNFTs[stakedNFTs.length - 1];
            NFTsStakedByUser[msg.sender].pop();
        }

        //Delete the NFTs staked details
        delete stepStaked[tokenId];
        
        //Mint the reward tokens to the staker
        token.Mint(msg.sender, reward);
        
        //Call updateStep 
        updateStep(stepInfo[currentStepID].totalNFTsStaked - 1);
    
        //Emit event
    }

    function claim(uint256 tokenId) external {
        //Check that the NFT has been staked
        require(stepStaked[tokenId] > 0,"ERR:NS");//NS => Not Staked

        //Check that the current step did not start this second - This is actually a security check to make sure a contact is not staking & unstaking to cause multiple steps to occur during the same second
        require(stepInfo[currentStepID].timeStepStarted < block.timestamp,"ERR:TS");//TS => Too Soon 

        //Check that the caller is the one that staked the NFT
        bool check = false;
        uint256 index = 0;
        uint256[] memory stakedNFTs = NFTsStakedByUser[msg.sender];
        for(uint256 i = 0; i < stakedNFTs.length;){

            if(stakedNFTs[i] == tokenId){
                check = true;
                index = i;
                break;
            }

            unchecked{
                i++;
            }
        }
        require(check,"ERR:DS");//DS => Didn't Stake

        //Calculate the due reward for the user
        uint256 reward = getDueReward(tokenId);

        //Get the current Step ID 
        uint256 currentStepID = latestStepID;

        //Set the step that the NFT was staked on as the next step
        stepStaked[tokenId] = currentStepID + 1;
        
        //Mint the reward tokens to the staker
        token.Mint(msg.sender, reward);
        
        //Call updateStep 
        updateStep(stepInfo[currentStepID].totalNFTsStaked);

        //Emit event
    }

    function updateStep(uint256 NFTsStaked) internal {
        //Get current Step ID
        uint256 currentStepID = latestStepID;

        if(currentStepID == 0){
            currentStepID = 1;
            latestStepID = currentStepID;
            stepInfo[currentStepID].totalNFTsStaked = NFTsStaked;
            stepInfo[currentStepID].timeStepStarted = block.timestamp;
        }else {
            stepInfo[currentStepID].timeStepEnded = block.timestamp - 1;
            stepInfo[currentStepID].totalRewardThisStep = stepInfo[currentStepID].treasury * (block.timestamp - 1 - stepInfo[currentStepID].timeStepStarted) / 100000;
            stepInfo[currentStepID + 1].treasury = stepInfo[currentStepID].treasury - stepInfo[currentStepID].totalRewardThisStep;
            stepInfo[currentStepID + 1].totalNFTsStaked = NFTsStaked;  

            latestStepID = currentStepID + 1;
        }

        timeLastUpdated = block.timestamp;
    }

    function getDueReward(uint256 tokenID) public view returns(uint256){
        //Get the step staked on
        uint256 StepStakedOn = stepStaked[tokenID];

        //Check if the NFT is staked
        if(StepStakedOn == 0) return 0;

        //Check if the step staked on equals the current step
        if(StepStakedOn == latestStepID){
            uint256 reward = stepInfo[StepStakedOn].treasury  * (block.timestamp - 1 - stepInfo[StepStakedOn].timeStepStarted) / 100000 / stepInfo[StepStakedOn].totalNFTsStaked;

            return reward; 
        }else{
            uint256 reward = 0;

            for(uint256 i = StepStakedOn; i < latestStepID;){

                reward += stepInfo[i].totalRewardThisStep / stepInfo[i].totalNFTsStaked;

                unchecked{
                    i++;
                }
            }


            reward += stepInfo[latestStepID].treasury  * (block.timestamp - 1 - stepInfo[latestStepID].timeStepStarted) / 100000 / stepInfo[latestStepID].totalNFTsStaked;

            return reward; 
        }
    }

    function forceUpdateStep() external {
        //Check that 12 hours have passed
        require(timeLastUpdated + 43200 <= block.timestamp,"ERR:NR");//NR => Not Ready

        //Call updateStep 
        updateStep(stepInfo[latestStepID].totalNFTsStaked);

        //Mint 1 Token to the caller as a reward for calling
        token.Mint(msg.sender, 1 * 10 ** 18);

        //Emit event
    }
}
