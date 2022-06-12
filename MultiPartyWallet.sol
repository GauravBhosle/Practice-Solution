// SPDX-License-Indentifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

contract MultiPartyWallet{
    event Deposit(address indexed sender,uint amount);
    event Submit(uint indexed txId);
    event Approve(address indexed owner,uint indexed txId);
    event Execute(uint indexed txId);

    address public Administrator;
    address[] public owners;
    mapping(address => bool) isOwner;
    mapping(uint => mapping(address => bool)) isApproved;
    mapping(uint => address) user;
    uint public percentage;
    
   

    struct Transaction{
        address to;
        uint value;
        bytes data;
        bool execute;
    }

    Transaction[] public transactions;
    mapping(address => uint) ownerIndex;

    constructor(address[] memory _owners, uint _percentage){
        require( _owners.length >0, "Please Enter Atleast one Address");
        require(_percentage<=100,"Invalid Percentage");

        for(uint i; i<_owners.length; i++){
            address owner=_owners[i];
            require(owner != address(0),"Invalid Owner Address");
            isOwner[owner]=true;
            owners.push(owner);
            ownerIndex[owner]=i;
        }
        percentage=_percentage;
        Administrator=msg.sender;
    }

    receive() external payable{
        emit Deposit(msg.sender,msg.value);
    }

    modifier onlyOwner(){
        require(isOwner[msg.sender],"Only Owner Can Submit Transactions");
        _;
    }

    modifier txExist(uint _txId){
        require(_txId<transactions.length,"This Transaction does not Exists");
        _;
    }

    modifier notApproved(uint _txId){
        require(!isApproved[_txId][msg.sender],"You have already Approved");
        _;
    }

    modifier notExecuted(uint _txId){
        require(!transactions[_txId].execute,"Transaction is Already Executed");
        _;
    }

    function submit(address _to, uint _value, bytes calldata _data) external onlyOwner{
        transactions.push(Transaction({
            to: _to,
            value: _value,
            data: _data,
            execute: false
        }));
        user[transactions.length-1]=msg.sender;
        emit Submit(transactions.length -1);
    } 

    function approve(uint _txId) external onlyOwner txExist(_txId) notApproved(_txId){
        isApproved[_txId][msg.sender]=true;
        emit Approve(msg.sender, _txId);
    }

    function execute(uint _txId) external onlyOwner txExist(_txId) notExecuted(_txId){
        require(user[_txId]==msg.sender,"Only user who has submitted transaction can execute it");
        require(_getPercentage(_txId) >= percentage,"Majority is Less than 60%");
        Transaction storage transaction=transactions[_txId];
        (bool success) = transaction.execute=true;
        transaction.to.call{
            value: transaction.value
        }(transaction.data);

        require(success,"Transaction Failed to execute");
        emit Execute(_txId);
    }

    function _getPercentage(uint _txId) private view returns(uint){
        uint percentageCount;
        for(uint i; i<owners.length; i++){
            if(isApproved[_txId][owners[i]]){
                percentageCount++;
            }
        }
       percentageCount=percentageCount*100/owners.length;
       return percentageCount;
    }

    function addOwner(address[] memory _owners) external {
        require(msg.sender==Administrator,"Only Administrator can add Owners");
        uint index=owners.length;
        for(uint i; i< _owners.length; i++){
            owners.push(_owners[i]);
            isOwner[_owners[i]]=true;
            ownerIndex[_owners[i]]=index;
            index++;
        }    
    }

    function removeOwner(address _owner) external{
            require(msg.sender==Administrator,"Only Administrator can remove Owners");
           require(isOwner[_owner]," You can't remove Owner which is not persent ");
           uint todelete=ownerIndex[_owner];
           delete owners[todelete];
    }

    function changeRequiredPercentage(uint _percentage) external{
        require(msg.sender==Administrator,"Only Administrator can change required percentage");
        percentage=_percentage;
    }
}