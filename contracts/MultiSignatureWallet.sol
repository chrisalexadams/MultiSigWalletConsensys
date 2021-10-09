pragma solidity 0.8.5;

contract MultiSigWallet {
    
    //global variables
    address[] public owners;
	uint public required;
	uint public transactionCount;
	
	//Mappings
	mapping (address => bool) public isOwner;
	mapping (uint => Transaction) public transactions;
	mapping (uint => mapping (address => bool)) public confirmations;
	
	//Modifiers
	modifier validRequirement(uint ownerCount, uint _required) {
		if(_required > ownerCount || _required == 0 || ownerCount == 0) 
		    revert();
		_;
	}
    //Constructor
    constructor(address[] memory _owners, uint _required) public validRequirement (_owners.length, _required){
	    for (uint i=0; i<_owners.length; i++) {
	         isOwner[_owners[i]] = true;
             }
	    owners = _owners;
	    required = _required;
    }
    
    //Events
    event Confirmation(address indexed sender, uint indexed transactionId);
    event Submission(uint indexed transactionId);
    event Execution(uint indexed transactionId);
    event ExecutionFailure(uint indexed transactionId);

    struct Transaction {
	    address destination;
        uint value;
        bytes data;
	    bool executed;
	}
	
    function addTransaction(address destination, uint value, bytes memory data) public payable returns (uint transactionId) {
	    transactionId = transactionCount;
	    transactions[transactionId] = Transaction ({
		    destination: destination,
		    value: value,
		    data: data,
		    executed: false
	    });
	transactionCount += 1;
	emit Submission(transactionId);
    }
    
    function submitTransaction(address destination, uint value, bytes memory data) public payable returns (uint transactionId) {
        require(isOwner[msg.sender]);
        transactionId = addTransaction (destination, value, data);
        confirmTransaction(transactionId);
    }
    
    function confirmTransaction (uint transactionId) public payable {
	    require(isOwner[msg.sender]);
	    require(transactions[transactionId].destination != address(0));
	    require(confirmations[transactionId][msg.sender] == false);
	    confirmations[transactionId][msg.sender] = true;
	    emit Confirmation(msg.sender, transactionId);
	    executeTransaction(transactionId);
    }
    
    function isConfirmed (uint transactionId) public view returns (bool) {
		uint count = 0;
		for(uint i=0; i<owners.length; i++) {
			if(confirmations[transactionId][owners[i]])
			      count += 1;
			if(count == required)
			     return true;
		}
	}
	
	function executeTransaction(uint transactionId) public payable {
        require(transactions[transactionId].executed == false);
        if (isConfirmed(transactionId)) {
            Transaction storage t = transactions[transactionId];
            t.executed = true;
            (bool success, bytes memory rdata) = t.destination.call{value: t.value}(t.data);
            if (success) 
                emit Execution(transactionId);
            else {
                emit ExecutionFailure(transactionId);
                t.executed = false;
            }
        }
    }
}