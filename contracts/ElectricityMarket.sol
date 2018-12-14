pragma solidity ^0.4.8;

import "./SmartMeters.sol";


contract ElectricityMarket {

    enum ContractState { NotCreated, Created, Accepted, WaitingForBuyerReport,
        WaitingForSellerReport, ReadyForWithdrawal, Resolved, TimedOut }

    struct Contract {
        address seller;                                                                     //??sellers address is the same as smart meter (SM)?
        address sellerSmartMeter;                                                           //??why isnt this the only seller address needed??
        address buyer;                                                                      //??buyers address is the same as SM??
        address buyerSmartMeter;                                                            //??why isnt this the only buyer address needed
        uint price;                                                                         //the price at which a unit of energy is sold
        uint electricityAmount;                                                             //the amount of electricity sold
        uint startTime;                                                                     //the start time should be 60s< //time defaults to block count not seconds
        uint endTime;                                                                       //the end time should be >1800s //time defaults to block count not seconds
        bool sellerReport;                                                                  //true if everything went OK
        bool buyerReport;                                                                   //true if everything went OK
        ContractState state;
    }

    modifier contractNotCreated(uint id) {                                                  //This is the ID of the sale see offer-objects.js 1349 - 1350
        if (contracts[id].state != ContractState.NotCreated) {                              //Does a contract exist? contract id's state isnt equal to contractstate not created
            revert();                                                                       //If contract doesnt exist throw
        }
        _;                                                                                  //Else if continue
    }

    modifier contractInState(uint id, ContractState state) {                                //This is the ID of the sale see offer-objects.js 1349 - 1350
        if (contracts[id].state != state) {                                                 //??is the time lock satisfied //??Has the sell amount been baught
            revert();                                                                       //??If contract isnt unlocked throw
        }
        _;                                                                                  //Else if continue
    }

    modifier waitingForSellerReport(uint id) {                                              //This is the ID of the sale see offer-objects.js 1349 - 1350
        if ((contracts[id].state != ContractState.Accepted) &&                              //Is the contract state not equal to accepted && 
            (contracts[id].state != ContractState.WaitingForSellerReport)) {                //Is the contract state not equal to waitingForSellerReport
            revert();                                                                       //If the conditions arnt satisfied throw
        }
        _;                                                                                  //Else if continue
    }

    modifier waitingForBuyerReport(uint id) {                                               //This is the ID of the sale see offer-objects.js 1349 - 1350
        if ((contracts[id].state != ContractState.Accepted) &&                              //Is the contract state not equal to accepted && 
            (contracts[id].state != ContractState.WaitingForBuyerReport)) {                 //Is the contract state not equal to waitingForBuyerReport 
            revert();                                                                       //If the conditions arnt satisfied throw
        }
        _;                                                                                  //Else if continue
    }

    modifier noOverlappingContracts(address smartMeter, uint startTime, uint endTime) {     //Chech that a smart meter doesnt have multiple contracts for the same time period 
        for (uint i = 0; i < contractsBySmartMeter[smartMeter].length; i++) {               //Create variable i as 0, increase value of i
            Contract memory c = contracts[contractsBySmartMeter[smartMeter][i]];            //Store into memory the current Smart Contract (SC) as C 
            if (doTimeslotsOverlap(startTime, endTime, c.startTime, c.endTime)) {           //When a new SC is created check its start-end times dont overlap
                revert();                                                                   //If they overlap throw
            }
        }
        _;                                                                                  //Else if continue
    }

    modifier ownsSmartMeter(address owner, address smartMeter) {                            //Does the address for the transaction match that of the SM
        if (owner != smartMeters.owner(smartMeter)) {                                       //If owner is not equal to smartMeter
            revert();                                                                       //If they are not equal throw
        }
        _;                                                                                  //Else if they are equal continue
    }

    modifier buyerSmartMeterOnly(uint id) {                                                 //This is the ID of the sale see offer-objects.js 1349 - 1350
        if (msg.sender != contracts[id].buyerSmartMeter) {                                  //??Is message senders address not equal to contract ID of the buyer's SM
            revert();                                                                       //If they are not equal throw
        }
        _;                                                                                  //Else if they are equal continue
    }

    modifier sellerSmartMeterOnly(uint id) {                                                //This is the ID of the sale see offer-objects.js 1349 - 1350
        if (msg.sender != contracts[id].sellerSmartMeter) {                                 //??Is message senders address not equal to contract ID of the sellers's SM
            revert();                                                                       //If they are not equal throw
        }
        _;                                                                                  //Else if they are equal continue
    }

    modifier condition(bool c) {                                                            //Check the status of C
        if (!c) {                                                                           //!c = opposite of C's state, so If the times overlap C = True then !C = False
            revert();                                                                       //If false throw
        }
        _;                                                                                  //Else if true then continue
    }

    modifier costs(uint price) {                                                            //Checks the price
        if (msg.value != price) {                                                           //Is the message value not equal to price?
            revert();                                                                       //If the message value is not equal to price throw
        }
        _;                                                                                  //If the message value is equal to price continue
    }

    mapping (uint => Contract) contracts;                                                   //Relate unsigned interger to Contract
    mapping (address => uint[]) contractsBySmartMeter;                                      //Relate address to unsigned interger[]
    SmartMeters smartMeters;


    // Minimum time from block.timestamp to startTime. The time needs to be long
    // enough, so that a few blocks are created in between, so that the smart
    // meters can be sure that the transmission is approved by the blockchain
    uint minTimeFromAcceptedToStart = 60;  // 1 minutes                                     //Defaults to block count not current time + x
    // Maximum time from endTime to smart meters reporting about how the
    // transmission went.
    uint maxTimeFromEndToReportDeadline = 1800;  // 30 minutes                              //Defaults to block count not current time + x

    event LogOffer(address seller, uint id, uint price, uint electricityAmount, uint startTime, uint endTime, address sellerSmartMeter);                                                //Record these values so that they can be called
    event LogAcceptOffer(address seller, uint id, uint price, uint electricityAmount, uint startTime, uint endTime, address sellerSmartMeter, address buyer, address buyerSmartMeter);  //Record these values so that they can be called
    event LogResolved(uint id, address seller, address buyer, address recipient);                                                                                                       //Record these values so that they can be called

    constructor() public {                                                                  //ElectricityMarket contract 
        smartMeters = new SmartMeters();                                                    //??
    }

    function makeOffer(uint id, uint price, uint electricityAmount, uint startTime, uint endTime, address sellerSmartMeter) public //Requre the variables id,price... in order to makeOffer
        contractNotCreated(id)                                                              //ID of a NEW contract, from modifer contractNotCreated
        condition(startTime < endTime)                                                      //Confirm that endtime is in the future from Start time, Time NOW not checked
        noOverlappingContracts(sellerSmartMeter, startTime, endTime)                        //Confrim that modifer noOverlappingContracts is True
        ownsSmartMeter(msg.sender, sellerSmartMeter)                                        //Confirm that messge sender owns the selling smart meter.
    {
        storeAndLogNewOffer(id, price, electricityAmount, startTime, endTime, sellerSmartMeter);    //Stores the offer 
    }

    function acceptOffer(uint id, address buyerSmartMeter) payable public                   //Requires the variables ID and buyerSmartMeter //Payable allows function to recieve ETH
        costs(contracts[id].price)                                                          //Get contract ID's price
        contractInState(id, ContractState.Created)                                          //Contract ID, update the contract state to created
        ownsSmartMeter(msg.sender, buyerSmartMeter)                                         //Confirm that the message sender is the owner of the buying SM
    {
        // Check if contract timed out
        if ((now + minTimeFromAcceptedToStart) > contracts[id].startTime) {                 //Check if time now + start time is more than contrats start time
            contracts[id].state = ContractState.TimedOut;                                   //Update contracts state to Timed Out
            return;                                                                         //Return values for Timed Out
        }

        contracts[id].buyer = msg.sender;                                                   //Set the contracts buyer id = message sender
        contracts[id].buyerSmartMeter = buyerSmartMeter;                                    //Set the contracts buyerSmartMeter to buyerSmartMeter
        contracts[id].state = ContractState.Accepted;                                       //Update the contracts state to Accepted

        emit LogAcceptOffer(contracts[id].seller, id, contracts[id].price, contracts[id].electricityAmount, contracts[id].startTime, contracts[id].endTime, contracts[id].sellerSmartMeter, msg.sender, buyerSmartMeter);  //emit calls event explicitly - Record these values so that they can be called
    }

    function sellerReport(uint id, bool report) public                                      //Requires variables ID and Report to generate seller report
        sellerSmartMeterOnly(id)                                                            //Check function sellerSmartMeterOnly has been succesfully run
        waitingForSellerReport(id)                                                          //Check function waitingForSellerReport has been succesfully run
    {
        if (hasReportDeadlineExpired(id)) {                                                 //Modifer of waitingForSellerReport, Has end time of contract exceeded now
            contracts[id].state = ContractState.ReadyForWithdrawal;                         //If now is after end time release funds
            return;                                                                         //Return values for Seller report
        }
        contracts[id].sellerReport = report;                                                //set Contract ID (sellerReport) to = report
        contracts[id].state = (contracts[id].state == ContractState.Accepted) ? ContractState.WaitingForBuyerReport : ContractState.ReadyForWithdrawal; //confirm contract state == accepted (? is a short cut for an IF function, : seperates true and false options of the IF) IF true : false
    }

    function buyerReport(uint id, bool report) public                                       //Require variables ID and report to generate buyer report
        buyerSmartMeterOnly(id)                                                             //Check function buyerSmartMeterOnly has been succesfully run
        waitingForBuyerReport(id)                                                           //Check function waitingforBuyerReport has been succesfully run
    {
        if (hasReportDeadlineExpired(id)) {                                                 //Check function hasReportDeadlineExpired has been succesfully run
            contracts[id].state = ContractState.ReadyForWithdrawal;                         //Set the contract state to ReadyForWithdrawal
            return;                                                                         //Return values for buyer report
        }
        contracts[id].buyerReport = report;                                                 //set buyerReport values to that of report
        contracts[id].state = (contracts[id].state == ContractState.Accepted) ? ContractState.WaitingForSellerReport : ContractState.ReadyForWithdrawal; //If contract state == accepted then (true) WaitingForSellerReport (false) ReadyForWithdrawal
    }

    function withdraw(uint id) public                                                       //Require variable contract?? ID to generate withdraw
    {
        if (contracts[id].state != ContractState.ReadyForWithdrawal) {                      //If state is not equal to state.ReadyForWithdrawal then
            makeReadyForWithdrawal(id);                                                     //Call functrion makeReadyForWithdrawal on ID
        }
        contracts[id].state = ContractState.Resolved;                                       //set state = Resolved

        address recipient;                                                                  //??

        if (!contracts[id].sellerReport) {                                                  //??Check if the seller is not qual to the buyer
            recipient = contracts[id].buyer;                                                
        }
        else if (contracts[id].buyerReport) {                                               //If the seller is equal to the buyer
            recipient = contracts[id].seller;                                               //??Check if the buyer is equal to the seller
        }
        else {
            recipient = this;                                                               //Return energy/ETH to buyer
        }

        emit LogResolved(id, contracts[id].seller, contracts[id].buyer, recipient);         //emit calls event explicitly - ??

        if (recipient != address(this)) {                                                   //Check if recipient is not equal to the address of the current account
            if (!recipient.send(contracts[id].price)) {                                     //??Check if not recipient send contract(id) price
                revert();                                                                   //If true throw 
            }
        }
    }

    // Assume that startTime < endTime for both timestamp pairs
    function doTimeslotsOverlap(uint startTime1, uint endTime1, uint startTime2, uint endTime2) private pure returns (bool) {       //Require start and end time of contract and contract stored in C variable, Pure = no network verification needed, dont read storage state or write to storage
        if ((endTime1 < startTime2) || (endTime2 < startTime1)) {                           //Command || means if A or B are true then proceed 
            return false;
        }
        return true;
    }

    function hasReportDeadlineExpired(uint id) private view returns (bool) {                //Requires contract ID see offer-objects.js 1349 - 1350 
        if ((contracts[id].endTime + maxTimeFromEndToReportDeadline) > now) {               //If endtime is after now return false if not return true
            return false;
        }
        return true;
    }

    // A helper made to avoid "stack too deep" error in makeOffer.                          //storage or mapping function?
    function storeAndLogNewOffer(uint id, uint price, uint electricityAmount, uint startTime, uint endTime, address sellerSmartMeter) private {
        contracts[id].seller = msg.sender;                                                  //seller = message sender(current address logged in to SC)
        contracts[id].price = price;                                                        //Store price in contacts(id) array under price
        contracts[id].electricityAmount = electricityAmount;                                //""
        contracts[id].startTime = startTime;                                                //""
        contracts[id].endTime = endTime;                                                    //""
        contracts[id].sellerSmartMeter = sellerSmartMeter;                                  //""
        contracts[id].state = ContractState.Created;                                        //""

        contractsBySmartMeter[sellerSmartMeter].push(id);                                   //appends latest set of values to array

        emit LogOffer(msg.sender, id, price, electricityAmount, startTime, endTime, sellerSmartMeter);      //emit calls event explicitly - Records the offer's values (id,)
    }

    // Change the state ReadyForWithdrawal if report deadline has expired. If
    // not succesful for any reason, then throw.
    function makeReadyForWithdrawal(uint id) private {
        if ((contracts[id].state == ContractState.Accepted                                  //If state == accepted
            || contracts[id].state == ContractState.WaitingForSellerReport                  //OR If state == waitingForSellerReport
            || contracts[id].state == ContractState.WaitingForBuyerReport)                  //OR If state == waitingforBuyerReport
            && hasReportDeadlineExpired(id))                                                //AND hasReportDeadlineExpired is true
        {
            contracts[id].state = ContractState.ReadyForWithdrawal;                         //then set state to ReadyForWithdrawal
            return;                                                                         //Return values
        }
        revert();                                                                           //If false throw
    }

    function getSeller(uint id) public view returns (address) {                             //Get the sellers contract ID see offer-objects.js 1349 - 1350
        return contracts[id].seller;                                                        //Returns that address' seller contract ID with out altering storage state
    }

    function getBuyer(uint id) public view  returns (address) {                             //Get the sellers contract ID see offer-objects.js 1349 - 1350
        return contracts[id].buyer;                                                         //Returns that address' buyer contract ID with out altering storage state
    }

    function getBuyerReport(uint id) public view  returns (bool) {                          //Get the sellers contract ID see offer-objects.js 1349 - 1350
        return contracts[id].buyerReport;                                                   //Returns that address' buyer report contract ID with out altering storage state
    }

    function getSellerReport(uint id) public view  returns (bool) {                         //Get the sellers contract ID see offer-objects.js 1349 - 1350
        return contracts[id].sellerReport;                                                  //Returns that address' seller report contract ID with out altering storage state
    }

    function isCreated(uint id) public view  returns (bool) {                               //Get the sellers contract ID see offer-objects.js 1349 - 1350
        return contracts[id].state != ContractState.NotCreated;                             //Returns that address' contract state (not if its not created) & ID with out altering storage state
    }

    function getState(uint id) public view  returns (ContractState) {                       //Get the sellers contract ID see offer-objects.js 1349 - 1350
        return contracts[id].state;                                                         //Returns that contract state & ID with out altering storage state
    }

    function getSmartMetersContract() public view  returns (address) {                      //Call the getSmartMetersContract into this SC
        return smartMeters;                                                                 //Return the SM contract
    }
}
