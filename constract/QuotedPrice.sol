pragma solidity 0.6.0;

import "./SafeMath.sol";
import "./SafeERC20.sol";

contract QuotedPrice {
        using SafeMath for uint256;
        using SafeERC20 for ERC20;
        address private owner;                                  
        address private _arbiter;                           

        
        bool _isDIS = false;                                
        address _otherAmountAddress;         
        uint256 _blockLimit = 9600;                          
        uint256 _maxErc20Token=100000000000;                
        mapping(address => QuotedPriceOrder) _orders;       
        mapping(address => ChallengeOrder) _challengeOrders;       
        mapping(uint256 => uint256) _quotedBlockMining;     
        mapping(uint256 => uint256) _quotedBlockTotal;     
        ERC20 _Token;
        Mining _miningContract;              
             

        
        struct QuotedPriceOrder {
          uint256 challengedState;                        
          uint256 isUsed;                                
          uint256 tokenAmount;                           
          uint256 blockNum;  
          uint256 price;  
          string coin;
        }
        
        
        struct ChallengeOrder {
          address quotedAddress;                           
          uint256 orderState;                      
          uint256 tokenAmount;    
          uint256 price;
        }
        event QuotedPriceAddress(address sendAddress, 
          uint256 erc20Amount,uint256 bLimit);
        event OfferTran(address tranSender, address tranToken, uint256 tranAmount,address otherToken, 
          uint256 otherAmount, address tradedContract, address tradedOwner);        
         
         
        constructor (address miningAddress,address tokenAddress,address arbiter) public {
            _miningContract = Mining(miningAddress);
             _Token = ERC20(tokenAddress);
            owner = msg.sender;
            _arbiter=arbiter;
         }
    
    function offer(uint256 erc20Amount) public{
        require(address(msg.sender) == address(tx.origin), "no contract");
        require(_isDIS, "is disable");
        QuotedPriceOrder memory order= _orders[msg.sender];
        require(order.isUsed==0, "exsit order");
        require(erc20Amount>=_maxErc20Token, "less token");

        createOffer(erc20Amount);
        _Token.safeTransferFrom(address(msg.sender), address(this), erc20Amount);
        uint256 miningAmount=_quotedBlockMining[block.number];
        if(miningAmount==0){
            _quotedBlockMining[block.number]=_miningContract.get_Mining();
        }
        _quotedBlockTotal[block.number]=erc20Amount.add(_quotedBlockTotal[block.number]);
    }
    
    /**
    * @dev 
    * @param erc20Amount
    */
    function createOffer( uint256 erc20Amount) private {
        emit QuotedPriceAddress(msg.sender, erc20Amount,_blockLimit);
        _orders[msg.sender]=QuotedPriceOrder(
            1,
            1,
            erc20Amount,
            block.number
        );
    }
    /**
    * @dev finishOrder
    */
    function finishOrder() public {
        require(address(msg.sender) == address(tx.origin), "no contract");
        QuotedPriceOrder storage order = _orders[msg.sender];
        require(order.isUsed==1, "order not exsit");
        require(order.challengedState==1, "order challenging");
        require(checkContractState(order.blockNum) == 1, "block short");
        order.isUsed=0;
        order.challengedState=4;
        if(order.tokenAmount>0){
            uint256 myMiningAmount = order.tokenAmount.mul(_quotedBlockMining[order.blockNum]).div(_quotedBlockTotal[order.blockNum]);
            uint256 maxMiningAmount = order.tokenAmount.div(100);
            uint256 takeAmount;
            if(maxMiningAmount<myMiningAmount){
               uint256 otherAmount = myMiningAmount.sub(maxMiningAmount);
               _Token.safeTransfer(_otherAmountAddress, otherAmount);
               takeAmount=maxMiningAmount+order.tokenAmount;
            }else{
               takeAmount=myMiningAmount+order.tokenAmount;
            }
               _Token.safeTransfer(address(msg.sender),takeAmount);
        }
    }

    
    function challenge(address qutedOrderOwner) public{
        require(address(msg.sender) == address(tx.origin), "no contract");
        require(_isDIS, "is disable");
        ChallengeOrder memory challengeOrder= _challengeOrders[msg.sender];
        require(challengeOrder.orderState==0, "order exsit");
        QuotedPriceOrder storage order= _orders[qutedOrderOwner];
        require(order.challengedState==1, "cannot be challenged");
        order.challengedState=2;
        uint256 challengeAmount=order.tokenAmount.mul(2);
        _Token.safeTransferFrom(address(msg.sender), address(this),challengeAmount);
        _challengeOrders[msg.sender]=ChallengeOrder(
            qutedOrderOwner,
            1,
            challengeAmount
            );
       
    }
    
     function arbSuccess(address qutedOrderOwner,address challengeOrderOwner) public onlyArbiter{
        ChallengeOrder memory challengeOrder= _challengeOrders[challengeOrderOwner];
        require(challengeOrder.orderState==1, "order not exsit");
        QuotedPriceOrder memory order= _orders[qutedOrderOwner];
        require(order.challengedState==2, "cannot be challenged");
        _orders[qutedOrderOwner].challengedState=3;
        _challengeOrders[challengeOrderOwner].orderState=2;
        uint256 reward=order.tokenAmount.mul(2).div(10).add(challengeOrder.tokenAmount);
         _Token.safeTransfer(challengeOrderOwner,reward);
    }
   
    
    function arbFail(address qutedOrderOwner,address challengeOrderOwner) public onlyArbiter{
        ChallengeOrder storage challengeOrder= _challengeOrders[challengeOrderOwner];
        require(challengeOrder.orderState==1, "order not exsit");
        QuotedPriceOrder storage order= _orders[qutedOrderOwner];
        require(order.challengedState==2, "cannot be challenged");
        order.challengedState=1;
        challengeOrder.orderState=3;
    }
  
    function offer2(uint256 erc20Amount) public onlyArbiter{
        require(address(msg.sender) == address(tx.origin), "no contract");
        require(_isDIS, "is disable");
        emit QuotedPriceAddress(msg.sender, erc20Amount,_blockLimit);
        _Token.safeTransferFrom(address(msg.sender), address(this), erc20Amount);
    }
 
    function checkContractState(uint256 createBlock) public view returns (uint256) {
        if (block.number.sub(createBlock) > _blockLimit) {
            return 1;
        }
        return 0;
    }
    
    function getOrder() view public returns (string memory) {
        bytes memory buf = new bytes(20000);
        uint256 index = 0;
        QuotedPriceOrder memory order= _orders[msg.sender];
        if(order.blockNum<1){
            buf[index++] = byte(uint8(32));
        }else{
            index = writeUInt(order.blockNum+_blockLimit, buf, index);
            buf[index++] = byte(uint8(44));
            index = writeUInt(order.blockNum, buf, index);
            buf[index++] = byte(uint8(44));
            index = writeUInt(order.tokenAmount, buf, index);
            buf[index++] = byte(uint8(44));
            if(order.isUsed==1){
                index = writeUInt(1, buf, index);
            }else if(order.isUsed==0){
                index = writeUInt(0, buf, index);
            }
        }
        bytes memory str = new bytes(index);
        while(index-- > 0) {
            str[index] = buf[index];
        }
        return string(str);
    }
    
    function writeUInt(uint256 iv, bytes memory buf, uint256 index) pure public returns (uint256) {
        uint256 i = index;
        do {
            buf[index++] = byte(uint8(iv % 10 +48));
            iv /= 10;
        } while (iv > 0);
        
        for (uint256 j = index; j > i; ++i) {
            byte t = buf[i];
            buf[i] = buf[--j];
            buf[j] = t;
        }
        
        return index;
    }

    function changeAmountAddress(address amountAddress) public onlyOwner {
        _otherAmountAddress= amountAddress;
    }
    function changeIsDIS(bool flag) public onlyOwner {
        _isDIS= flag;
    }
    
    function changeBlockLimit(uint32 limit) public onlyOwner {
        _blockLimit= limit;
    }
    
    function changeMining(address miningAddress) public onlyOwner {
        _miningContract= Mining(miningAddress);
    }
    function changeMaxErc20Token(uint256 maxErc20Token) public onlyOwner {
        _maxErc20Token= maxErc20Token;
    }
    function changeArbiter(address arbiter) public onlyOwner {
        _arbiter= arbiter;
    }
    
    modifier onlyOwner(){
        require(msg.sender == owner);
        _;
    }
    modifier onlyArbiter(){
        require(_arbiter == msg.sender);
        _;
    }
  
	}
  interface Mining {
     function get_Mining() external returns (uint256);
  }
