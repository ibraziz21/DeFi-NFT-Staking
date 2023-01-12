// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.17;
import "./token/mobtoken.sol";
import "./ERC721Character.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract Staking is IERC721Receiver {
    error InvalidInput();
    error Unauthorized();
    error PoolAlreadyExists();
    error PoolNotFound();
    error PoolFilled();
    error Forbidden();
    error InsufficientRewards();

    event PoolCreated(uint8 id, uint16 max);
    event Staked(address staker, uint tokenID, uint8 poolID);
    event StakingStarted(uint256 startTime, uint256 endTime, uint256 duration);


//Staking Pools, each pool with different reward rate
    struct Pool {
        uint16 slots;
        uint16 maxSlots;
        uint rewardsPerDay;
        bool stakingActive;
    }


    struct StakedNFT {
        address nftOwner;
        uint8 poolID;
        uint16 slotNo;
        uint startTime;
        uint rewardsEarned;
    }

    IMobToken private token;
    ICharacter private character;

    address private admin;

    mapping(uint8 => bool) public poolExists;
    mapping(uint => StakedNFT) public stakedNFT;
    mapping(uint8 => Pool) public poolDetails;

    constructor(address _token, address _character) {
        if (_token == address(0) || _character == address(0))
            revert InvalidInput();
        token = IMobToken(_token);
        character = ICharacter(_character);
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        if (msg.sender != admin) revert Unauthorized();
        _;
    }
    /*
                ADMIN FUNCTIONS
    */

    function createPool(uint8 _poolID, uint16 _maxSlots) external onlyAdmin {
        if (poolExists[_poolID]) revert PoolAlreadyExists();
        Pool storage newPool = poolDetails[_poolID];
        newPool.maxSlots = _maxSlots;

        emit PoolCreated(_poolID, _maxSlots);
    }
    function setRewardsPerDay(
        uint8 _poolID,
        uint _rewardsPerDay
    ) external onlyAdmin {
        if(_poolID == 0 || _rewardsPerDay == 0) revert InvalidInput();
        Pool storage pool = poolDetails[_poolID];
        pool.rewardsPerDay = _rewardsPerDay;

    }
    /* 
        STAKE, CLAIM, UNSTAKE
    */

    function stakeNFT(uint _tokenID, uint8 _poolID) external {
        if (character.ownerOf(_tokenID) != msg.sender) revert Unauthorized();
        if (!poolExists[_poolID]) revert PoolNotFound();

        Pool storage stakingPool = poolDetails[_poolID];
        if (stakingPool.slots == stakingPool.maxSlots) revert PoolFilled();
        character.transferFrom(msg.sender, address(this), _tokenID);
        stakingPool.slots++;

        StakedNFT storage newStake = stakedNFT[_tokenID];
        newStake.nftOwner = msg.sender;
        newStake.slotNo = stakingPool.slots;
        newStake.poolID = _poolID;
        newStake.startTime = block.timestamp;

        emit Staked(msg.sender, _tokenID, _poolID);
    }


    

    function claimUnstake(uint8 _poolId, uint _id, bool unstake) internal {
        if(_poolId == 0 || _id == 0) revert InvalidInput();
        if(character.ownerOf(_id)!= msg.sender) revert Unauthorized();
        
        Pool memory pools = poolDetails[_poolId];
        uint rewards = pools.rewardsPerDay *10 **18;

        StakedNFT storage claims = stakedNFT[_id];

        uint daysStaked = (block.timestamp-claims.startTime)/ 1 days;
        uint totalRewards = rewards * daysStaked;
        claims.startTime = block.timestamp;
        token.mintRewards(totalRewards);

        if(unstake){
            delete stakedNFT[_id];
        }
    }

    function unstakeNFT(uint8 _poolId, uint _tokenId) external {
        if(!poolExists[_poolId] || _tokenId == 0) revert InvalidInput();
        if(character.ownerOf(_tokenId)!= msg.sender) revert Unauthorized();
        claimUnstake(_poolId,_tokenId, true);
    }
    function claim (uint8 _poolId, uint _tokenId) external {
        if(!poolExists[_poolId]) revert PoolNotFound();
        if(character.ownerOf(_tokenId)!= msg.sender) revert Unauthorized();
        claimUnstake(_poolId,_tokenId, false);
    }


    function onERC721Received(
        address,
        address from,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        if (from != address(0x0)) revert Forbidden();
        return IERC721Receiver.onERC721Received.selector;
    }
}
