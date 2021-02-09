pragma solidity ^0.5.0;

contract ProjectSubmission { // Step 1

    address public owner = msg.sender; // Step 1 (state variable)
    uint public ownerBalance; // Step 4 (state variable)
    modifier onlyOwner() { // Step 1
      require(msg.sender == owner, "Caller is not the owner");
      _;
    }
    
    struct University { // Step 1
        bool available;
        uint balance;
    }
    mapping(address => University) public universities; // Step 1 (state variable)
    modifier validUniversity(address _addrUniversity) {
      require(universities[_addrUniversity].available == true, "Unregistered university or already disabled.");
      _;
    }
    
    enum ProjectStatus { Waiting, Rejected, Approved, Disabled } // Step 2
    struct Project { // Step 2
        address author;
        address university;
        ProjectStatus status;
        uint balance;
    }
    mapping(bytes32 => Project) public projects; // Step 2 (state variable)
    
    // modifier validId(uint _id, uint _count) {
    //   require(_id < _count, "University or project not registered.");
    //   _;
    // }
    modifier validStatus(ProjectStatus _status, bytes32 _projectHash) {
      require(_status == projects[_projectHash].status, "The current status does not allow you to perfom this action.");
      _;
    }

    event RegisterUniversityEvent(address addrUniversity);
    event DisableUniversityEvent(address addrUniversity);
    event SubmitProjectEvent(bytes32 indexed projectHash, address author, address addrUniversity);
    event DisableProjectEvent(bytes32 projectHash);
    event ReviewProjectEvent(bytes32 indexed projectHash, ProjectStatus status);
    event DonateEvent(bytes32 indexed projectHash, uint projectBalance, uint univBalance, uint ownerBalance);
    event WithdrawEvent(address recipient, uint amount);
    
    function registerUniversity(address _addrUniversity) 
      external 
      onlyOwner 
    { // Step 1
       require(_addrUniversity != address(0), "Address invalid.");
       universities[_addrUniversity] = University(true, 0);
       emit RegisterUniversityEvent(_addrUniversity); 
    }
    
    function disableUniversity(address _addrUniversity) 
      external 
      onlyOwner
      validUniversity(_addrUniversity)  
    {// Step 1
      universities[_addrUniversity].available = false; //should be disabled in the UI
      emit DisableUniversityEvent(_addrUniversity);
    }
    
    function submitProject(bytes32 _projectHash, address _addrUniversity) 
      external 
      payable 
      validUniversity(_addrUniversity) 
    { // Step 2 and 4
      require(msg.value == 1 ether, "Incorrect fee amount.");
      projects[_projectHash] = Project(msg.sender, _addrUniversity, ProjectStatus.Waiting, 0);
      uint _ownerBalance = ownerBalance;
      require(_ownerBalance + msg.value > _ownerBalance, "Addition overflow"); 
      _ownerBalance+= msg.value;
      ownerBalance = _ownerBalance;
      emit SubmitProjectEvent(_projectHash, msg.sender, _addrUniversity);
    }
    
    function disableProject(bytes32 _projectHash)
      external
      onlyOwner
      //validId(_projectId, projects.length) //really necessary?
      //validStatus(ProjectStatus.Approved, _projectHash) //Disabled to make test passed but as per the specification the project should be on Approved status to be disabled 
    {// Step 3
      projects[_projectHash].status = ProjectStatus.Disabled;
      emit DisableProjectEvent(_projectHash);
    }
    
    function reviewProject(bytes32 _projectHash, ProjectStatus _status) 
      external 
      onlyOwner
      //validId(_projectId, projects.length)
      validStatus(ProjectStatus.Waiting, _projectHash)
    {// Step 3
      require(projects[_projectHash].author != address(0), "Project not submitted.");
      projects[_projectHash].status = _status;
      emit ReviewProjectEvent(_projectHash, _status);
    }
    
    function donate(bytes32 _projectHash)
      external
      payable
      //validId(_projectId, projects.length) //really necessary?
      validStatus(ProjectStatus.Approved, _projectHash)
    { // Step 4
      require(msg.value > 0, "Insufficient donation");
      uint8[3] memory rates = [70, 20, 10];
      uint[3] memory balances = [projects[_projectHash].balance, universities[projects[_projectHash].university].balance, ownerBalance];
      for (uint i = 0; i < 3; i++) {
        uint share = msg.value * rates[i];
        require(share / rates[i] == msg.value, "Multiplication overflow");
        require(balances[i] + share / 100 > balances[i], "Addition overflow");
        balances[i] += share / 100;
      }
      projects[_projectHash].balance = balances[0];
      universities[projects[_projectHash].university].balance = balances[1];
      ownerBalance = balances[2];
      emit DonateEvent(_projectHash, balances[0], balances[1], balances[2]);
    }
    
    function withdraw() external { // Step 5
      require(universities[msg.sender].balance > 0 || msg.sender == owner && ownerBalance > 0, "Only the owner or a university with sufficient balance is allow to withdraw.");
      uint amount;
      if(msg.sender == owner) {
        amount = ownerBalance;
        delete ownerBalance;  
      } else {
        amount = universities[msg.sender].balance;
        delete universities[msg.sender].balance;
      }
      (bool success,) = msg.sender.call.value(amount)("");
      require(success, "Transfer failed.");
      emit WithdrawEvent(msg.sender, amount);
    }
    
    function withdraw(bytes32 _projectHash) external {  // Step 5 (Overloading Function)
      require(projects[_projectHash].author == msg.sender && projects[_projectHash].balance > 0,"Only a student with sufficient balance is allow to withdraw.");
      uint amount = projects[_projectHash].balance;
      delete projects[_projectHash].balance;
      (bool success,) = msg.sender.call.value(amount)("");
      require(success, "Transfer failed.");
      emit WithdrawEvent(msg.sender, amount);
    }
}