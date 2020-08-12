pragma solidity 0.6.0;

import "./SafeMath.sol";
import "./SafeERC20.sol";


contract Mining {
    using SafeMath for uint256;
    ERC20 _tokenContract;
    using SafeERC20 for ERC20;

    event MiniAmountLog(uint256 nowBlock, uint256 blockAmount);
    address _quotedPriceAddress;                        
    uint256 _preMiningAmount ;             
    uint256 _latestMining;                     
    uint256 _latestMiningAmount;                       
    address owner;                                      
    constructor(address tokenAddress) public {
        _tokenContract = ERC20(tokenAddress);
        owner = msg.sender;
    }
    
    function get_Mining() public  returns (uint256) {
        require(address(msg.sender) == _quotedPriceAddress, "do not have enough clearance");
        uint256 miningAmount = countMiningAmount();
        if (_tokenContract.balanceOf(address(this)) < miningAmount){
            miningAmount = _tokenContract.balanceOf(address(this));
        }
        _tokenContract.safeTransfer(address(msg.sender), miningAmount);
        emit MiniAmountLog(block.number,miningAmount);
        return miningAmount;
      }
    
    function countMiningAmount() private returns (uint256) {
        uint256 blockDiff = block.number.sub(_latestMining);
        uint256 miningAmount=blockDiff.mul(_preMiningAmount);
        _latestMining = block.number;
        _latestMiningAmount=miningAmount;
        return miningAmount;
    }
    
    function changeQuotedAddress(address target) public onlyOwner {
        _quotedPriceAddress=target;
    }
    
    function changePreMiningAmount(uint256 amount) public onlyOwner {
        _preMiningAmount=amount;
    }
    
    function changeLatestMining(uint256 amount) public onlyOwner {
        _latestMining=amount;
    }
   
    modifier onlyOwner(){
        require(msg.sender == owner);
        _;
    }

}
