pragma solidity ^0.4.16;

import {Memory} from "github.com/ethereum/solidity-examples/blob/master/src/unsafe/Memory.sol";
import {Bytes} from "github.com/ethereum/solidity-examples/blob/master/src/bytes/Bytes.sol" ;
contract EMCUR {

// --ストラクチャ定義 Start--
	// ユーザ情報
	struct User {
		// ユーザID
		uint userId;
		// ユーザ名
		bytes32 userName;
        // ユーザーアカウントアドレス
        address userAccountAddress;
        // 削除フラグ
		bool delFlag;
	}
	// ユーザグループ情報
	struct UserGroup {
		// ユーザグループID
		uint userGroupId;
		// ユーザグループ名
		bytes32 userGroupName;
        // 削除フラグ
		bool delFlag;
	}

	// 口座情報
	struct Account {
	    // 店番口座番号
	    bytes32 branchAccountNo; 
	    // 店番
	    bytes32 branchNo;
		// 口座番号
		bytes32 accountNo;
        // 口座名義
        bytes32 accountHolderName;
		// 口座種別
		uint accountType;
		// 通貨
		bytes32 currency;
		// 残高
		uint balance;
		// 作成タイムスタンプ
		uint createTimestamp;
		// 更新タイムスタンプ
		uint updateTimestamp;
        // 削除フラグ
        bool delFlag;
	}

	// 送金依頼情報
	struct RemmitanceRequest {
        // トランザクションID
        uint requestId;
        // 種別
        uint requestType;
        // 送金元店番
        bytes32 branchNo;
        // 送金元口座番号
        bytes32 accountNo;
        // 送金元口座名義
        bytes32 accountHolderName;
        // 送金元通貨
        bytes32 fromCurrency;
        // 送金先通貨
        bytes32 toCurrency;
        // レート
        bytes32 rate;
        // 送金元元本
        uint fromAmount;
        // 送金先元本
        uint toAmount;
        // 申込日
        bytes32 applicationDate;
        // 実行予定日
        bytes32 valueDate;
        // タイムスタンプ
        uint timestamp;
        // ipfsハッシュ1
        bytes32 ipfsHashFirst ;
        // ipfsハッシュ2
        bytes32 ipfsHashSecond ;
	}
	// 処理フローの親
	struct ProcessFlow {
	    // id
	    uint processFlowId;
	    // requestId
	    uint requestId;
	}
	// 各プロセス
	struct Process {
	    // processId
	    uint processId;
	    // flow id
	    uint processFlowId;
	    // processNumber
	    uint processNumber;
	    // 操作可能なUserGroupID
	    uint targetUserGroupId;
	    // 前提となるprocessNumber
	    uint[MAX_PREV_PROCESS_NUM] prevProcessNumber ;
	    // status
	    uint status;
	    // 処理時のタイムスタンプ
	    uint doneTimestamp;
	    // 処理時のユーザーID
	    uint doneUserId;
	    // ipfsハッシュ1
	    bytes32 ipfsHashFirst;
	    // ipfsハッシュ2
	    bytes32 ipfsHashSecond;
	}
	
	//LinkedIndexListの要素
	struct LinkedIndexlement {
	    //前の要素へのリンク(1つ目のmappingのキー)
	    bytes32 prevElementLink ;
	    //次の要素へのリンク(mappingのキー)
	    bytes32 nextElementLink ;
	    //インデックス
	    uint index ;
	}
	
	//LinkedIndexListのMaster
	struct LinkedIndexMaster {
	    //リストの最初の要素
	    bytes32 firstElementKey ;
	    //リストの最後の要素
	    bytes32 lastElementKey ;
	}
	
// --ストラクチャ定義 End--

// --定数定義 Start--
    // 種別(デフォルト)
    uint constant TYPE_DEF = 0;
    // processflowに設定できるプロセスの最大数
    uint constant MAX_PROCESS_NUM =20;
    // processに設定する前提プロセスの最大数
    uint constant MAX_PREV_PROCESS_NUM =5;
    //processのステータス（未着手)
    uint constant PROC_STATUS_WAITING=0;
    
    // --LinkedIndexListのキー--
    // UserGroupとStatusからProcessを探すインデックスのタイプ
    // 2byte type,4byte UserGroupId,1byte status
    bytes2 constant INDEX_TYPE_PROCESS_BY_USERGROUP_STATUS = "a1";
    
// --定数定義 End--

// --変数定義 Start--
    //userId→User
	mapping (uint => User) userList;
    //branchAccountNo→Account
    mapping (bytes32 => Account) accountList;
    //requestId→RemmitanceRequest
	mapping (uint => RemmitanceRequest) remmitanceRequestList;
    //userGroupId =>UserGroup
    mapping (uint => UserGroup) userGroupList;
    //processFlowId =>ProcessFlow
    mapping (uint => ProcessFlow) processFlowList;
    //processId=>Process
    mapping (uint => Process) processList;
        
    // --index--
    //Userが属するUserGroupIdのリスト
    mapping (uint => uint[]) userGroupIdByUserIdIndex;
    //UserGroupが保有するUserIdのリスト
    mapping (uint => uint[]) userIdByUserGroupIdIndex;
    //ProcessFlowが持つProcessId群
    mapping (uint => uint[]) processIdByProcessFlowIdIndex;
    //processFlowが持つProcessNumberのステータス 添え字：processNumber 値：status
    mapping (uint => uint[]) processStatusByProcessFlowIdIndex;
    
    // インデックスを持つ汎用的なLinked List
    mapping (bytes32 => mapping(bytes32 => LinkedIndexlement)) linkedIndexList;
    // LinkedIndexListのMaster
    mapping (bytes32 => LinkedIndexMaster) linkedIndexListMaster;  
    
    //counter
    uint private userCounter = 0;
	uint private requestCounter = 0;
	uint private processFlowCounter = 0;
	uint private processCounter = 0;
// --変数定義 End--
    
// --Public関数定義 Start--
    // ログ
    event remmitanceRequestLog(uint _requestId,uint _status);

    // ビジネスロジック
    // 送金依頼登録
	function newRemmitanceRequest(uint _requestType,bytes32 _branchNo,bytes32 _accountNo,bytes32 _accountHolderName,
	    bytes32 _fromCurrency,bytes32 _toCurrency,bytes32 _rate,uint _fromAmount,uint _toAmount,bytes32 _applicationDate,
	    bytes32 _valueDate,bytes32 _ipfsHashFirst,bytes32 _ipfsHashSeond) public returns(bool result) {

        //送金依頼の登録
        requestCounter++;
        remmitanceRequestList[requestCounter].requestId = requestCounter ;
        remmitanceRequestList[requestCounter].requestType = _requestType ;
        remmitanceRequestList[requestCounter].branchNo = _branchNo ;
        remmitanceRequestList[requestCounter].accountNo = _accountNo ;
        remmitanceRequestList[requestCounter].accountHolderName = _accountHolderName ;

        remmitanceRequestList[requestCounter].fromCurrency = _fromCurrency ;
        remmitanceRequestList[requestCounter].toCurrency =  _toCurrency ;
        remmitanceRequestList[requestCounter].rate = _rate ;

        remmitanceRequestList[requestCounter].fromAmount =  _fromAmount ;
        remmitanceRequestList[requestCounter].toAmount =  _toAmount ;

        remmitanceRequestList[requestCounter].applicationDate =  _applicationDate ;
        remmitanceRequestList[requestCounter].valueDate =  _valueDate ;

        remmitanceRequestList[requestCounter].timestamp = block.timestamp ;        

        remmitanceRequestList[requestCounter].ipfsHashFirst =  _ipfsHashFirst ;
        remmitanceRequestList[requestCounter].ipfsHashSecond =  _ipfsHashSeond ;
        
        //processflowの作成
        processFlowCounter++ ;
        processFlowList[processFlowCounter].processFlowId = processFlowCounter ;
        processFlowList[processFlowCounter].requestId = requestCounter ;
        
        remmitanceRequestLog(requestCounter,1) ;
        return true;
	}
	
	function getRemmitanceRequest(uint _requestId) public constant returns(bytes32[14] remittanceRequest) {

        //送金依頼の取得
        remittanceRequest[0] = bytes32(remmitanceRequestList[_requestId].requestId) ;
        remittanceRequest[1] = bytes32(remmitanceRequestList[_requestId].requestType) ;
        remittanceRequest[2] = remmitanceRequestList[_requestId].branchNo ;
        remittanceRequest[3] = remmitanceRequestList[_requestId].accountNo ;
        remittanceRequest[4] = remmitanceRequestList[_requestId].accountHolderName ;
        remittanceRequest[5] = remmitanceRequestList[_requestId].fromCurrency ;
        remittanceRequest[6] = remmitanceRequestList[_requestId].toCurrency ;
        remittanceRequest[7] = bytes32(remmitanceRequestList[_requestId].fromAmount) ;
        remittanceRequest[8] = bytes32(remmitanceRequestList[_requestId].toAmount) ;
        remittanceRequest[9] = remmitanceRequestList[_requestId].applicationDate ;
        remittanceRequest[10] = remmitanceRequestList[_requestId].valueDate ;
        remittanceRequest[11] = bytes32(remmitanceRequestList[_requestId].timestamp) ;
        remittanceRequest[12] = remmitanceRequestList[_requestId].ipfsHashFirst ;
        remittanceRequest[13] = remmitanceRequestList[_requestId].ipfsHashSecond ;

        return remittanceRequest;
	}	
	// processFlowへのprocess追加
	function putProcess(uint _processFlowId,uint _processNumber,uint _targetUserGroupId,uint[MAX_PREV_PROCESS_NUM] _prevProcessNumber,
        bytes32 _ipfsHashFirst,bytes32 _ipfsHashSecond) public returns(bool result) {
	    
	    processCounter++ ;

	    //processListへの追加
	    processList[processCounter].processId = processCounter ;
	    processList[processCounter].processFlowId = _processFlowId ;
	    processList[processCounter].processNumber = _processNumber ;
	    processList[processCounter].targetUserGroupId = _targetUserGroupId ;
	    processList[processCounter].prevProcessNumber = _prevProcessNumber ;
	    processList[processCounter].status = PROC_STATUS_WAITING ;
	    processList[processCounter].ipfsHashFirst = _ipfsHashFirst ;
	    processList[processCounter].ipfsHashSecond = _ipfsHashSecond ;

        //processFlowとの関連付け
        processIdByProcessFlowIdIndex[_processFlowId].push(processCounter) ;
        
        //UserGroupId・Statusとの関連付け
        bytes32 key1 ;
        key1.concat(INDEX_TYPE_PROCESS_BY_USERGROUP_STATUS) ;
        
        pushLinkedIndexList(INDEX_TYPE_PROCESS_BY_USERGROUP_STATUS + bytes4(_targetUserGroupId) + bytes1(PROC_STATUS_WAITING),
        bytes32(processCounter),processCounter) ;
	    
	    return true;
	    
	}
	//LinkedIndexListへのアクセス nextKey2:ページングなどリストを続きから取得する場合に前回の最後の要素
	function getLinkedIndexListElements(bytes32 _key1,bytes32 _lastKey2) public constant returns(uint[10] resultIndexList,bytes32 lastKey2){
	    // 最初に取得する要素を取得
	    bytes32 currentElementKey ;
	    if(_lastKey2 == bytes32(0)){
	        //最初の要素から取得
	        currentElementKey = linkedIndexListMaster[_key1].firstElementKey ;
	    }else{
	        //続きの要素から取得
	        currentElementKey = linkedIndexList[_key1][_lastKey2].nextElementLink ;	        
	    }
	    
	    //一度に返す要素数分LinkedListから結果リストに格納
	    for(uint i = 0; i < resultIndexList.length ;i++){
	        resultIndexList[i] = linkedIndexList[_key1][currentElementKey].index ;
	        //最後の要素はmappingのキーも返す(値を持つ要素の場合のみ格納)
	        if( resultIndexList[i] != 0){
	            lastKey2 = currentElementKey ;
	        }
	        currentElementKey = linkedIndexList[_key1][currentElementKey].nextElementLink ;
	    }
	}
	function pushLinkedIndexList(bytes32 _key1,bytes32 _key2,uint _index) public returns(bool){
	    //対象のIndexListのマスターから最後の要素を取得
	    bytes32 lastElementKey = linkedIndexListMaster[_key1].lastElementKey;
	    
	    //今回が最初の要素の場合、最初の要素を更新
	    if(linkedIndexListMaster[_key1].firstElementKey == bytes32(0)){
	        linkedIndexListMaster[_key1].firstElementKey = _key2 ;
	    }else{
	        //最初の要素じゃない場合、前の要素を更新
	        linkedIndexList[_key1][lastElementKey].nextElementLink = _key2 ;
	    }
	    
	    //要素を追加
	    linkedIndexList[_key1][_key2].prevElementLink = lastElementKey ;
	    linkedIndexList[_key1][_key2].nextElementLink = bytes32(0);
	    linkedIndexList[_key1][_key2].index = _index;
	    
	    //最後の要素を更新
	    linkedIndexListMaster[_key1].lastElementKey = _key2 ;
	    
	    return true ;
	    
	}
	function removeLinkedIndexList(bytes32 _key1,bytes32 _key2) public returns(bool){
	    //対象のIndexListの前後のリンクを付け替える
	    bytes32 prevElementLink = linkedIndexList[_key1][_key2].prevElementLink;
	    bytes32 nextElementLink = linkedIndexList[_key1][_key2].nextElementLink;

        //削除対象の要素が最初の要素の場合
        if(linkedIndexListMaster[_key1].firstElementKey == _key2){
            //次の要素があれば、最初の要素を更新する
            if(nextElementLink == bytes32(0)){
            }else{
                linkedIndexListMaster[_key1].firstElementKey = nextElementLink ;
            }
        }else{
    	    //前の要素のリンク付け替え
    	    linkedIndexList[_key1][prevElementLink].nextElementLink = nextElementLink ;            
        }

        //削除対象の要素が最後の要素の場合
        if(linkedIndexListMaster[_key1].lastElementKey == _key2){
            //前の要素があれば、最後の要素を更新する
            if(prevElementLink == bytes32(0)){
            }else{
                linkedIndexListMaster[_key1].lastElementKey = prevElementLink ;
            }            
        }else{
    	    //次の要素のリンク付け替え
    	    linkedIndexList[_key1][nextElementLink].prevElementLink = prevElementLink ;
        }
	    
	    //解放
	    delete linkedIndexList[_key1][_key2] ;
	    
	    return true ;
	}

    // indexリストの取得
//     function getUserAccountIndexDesc(uint _userId,uint _startIndex) public constant returns(bytes32[10] accountIndexList ){
        
//         uint num = userAccountIndex[_userId].length;
// 		uint counter = 0;
// 		uint indexIndex = num - 1 - _startIndex;
		
// 		while (counter <= indexIndex) {
// 			if (counter >= 10) {
// 				 break;
// 			}
			
// 			accountIndexList[counter] = userAccountIndex[_userId][indexIndex - counter];
			
// 			counter++;
// 		}
//     }
//     // indexリストの取得
//     function getUserTransactionIndexDesc(uint _userId,uint _startIndex) public constant returns(uint[10] transactionIndexList ){
        
//         uint num = userTransactionIndex[_userId].length;
// 		uint counter = 0;
// 		uint indexIndex = num - 1 - _startIndex;
		
// 		while (counter <= indexIndex) {
// 			if (counter >= 10) {
// 				 break;
// 			}
			
// 			transactionIndexList[counter] = userTransactionIndex[_userId][indexIndex - counter];
			
// 			counter++;
// 		}
//     }

// 	// ユーザの参照
// 	function getUserInfo(uint _userId) public constant returns(bytes32[3] userInfo) {
			
// 		// ユーザ情報の参照
// 		userInfo[0] = bytes32(userInfoList[_userId].userId);
//         userInfo[1] = userInfoList[_userId].userName;
//         userInfo[2] = userInfoList[_userId].userAddress;

// 		return userInfo;
// 	}
//     // ユーザの登録
// 	function registUserInfo(bytes32 _userName, bytes32 _userAddress) public returns(uint userId) {
			
// 		// ユーザ情報の登録
// 		userCounter++;
//         userInfoList[userCounter].userId = userCounter;
// 		userInfoList[userCounter].userName = _userName;
//         userInfoList[userCounter].userAddress = _userAddress;
// 		userInfoList[userCounter].delFlg = false;
		
// 		return userInfoList[userCounter].userId;
// 	}
	
// 	// ユーザの更新
// 	function updateUserInfo(uint _userId,bytes32 _userName, bytes32 _userAddress) public returns(bool result) {
		
// 		// ユーザ登録していない場合はエラーを返す
// 		if (checkUserExistence(_userId) == false) {
// 			return false;
// 		}
		
// 		// ユーザ情報の登録
// 		userInfoList[_userId].userName = _userName;
// 		userInfoList[_userId].userAddress = _userAddress;
		
// 		return true;
// 	}
	
// 	// ユーザの削除
// 	function deleteUserInfo(uint _userId) public returns(bool result) {
		
// 		// ユーザ登録していない場合はエラーを返す
// 		if (checkUserExistence(_userId) == false) {
// 			return false;
// 		}
		
// 		// @ToDo 削除のための条件を追加
		
		
// 		// ユーザ情報の更新
// 		userInfoList[_userId].delFlg = true;
		
// 		return true;
// 	}
// 	// 口座の参照
// 	function getAccountInfo(bytes32 _accountNo) public constant returns(bytes32[6] accountInfo) {
			
// 		// ユーザ情報の参照
// 		accountInfo[0] = accountInfoList[_accountNo].accountNo;
//         accountInfo[1] = accountInfoList[_accountNo].accountHolderName;
// 		accountInfo[2] = bytes32(accountInfoList[_accountNo].accountType);
// 		accountInfo[3] = accountInfoList[_accountNo].currency;
// 		accountInfo[4] = bytes32(accountInfoList[_accountNo].balance);
// 		accountInfo[5] = bytes32(accountInfoList[_accountNo].userId);

//         return accountInfo;
// 	}	
//     // 口座開設
// 	function registAccountInfo(bytes32 _accountNo,bytes32 _accountHolderName, uint _accountType,bytes32 _currency,uint _balance,uint _userId) public returns(bool result) {
			
// 		// 口座情報の登録
//         accountInfoList[_accountNo].accountNo = _accountNo;
// 		accountInfoList[_accountNo].accountHolderName = _accountHolderName;
// 		accountInfoList[_accountNo].accountType = _accountType;
//         accountInfoList[_accountNo].currency = _currency;
//         accountInfoList[_accountNo].balance = _balance;
//         accountInfoList[_accountNo].userId = _userId;
//         accountInfoList[_accountNo].createTimestamp = block.timestamp;
//         accountInfoList[_accountNo].updateTimestamp = block.timestamp;
//         accountInfoList[_accountNo].delFlg = false;
        
//         userAccountIndex[_userId].push(_accountNo);
		
// 		return true;
// 	}
    
//     //口座閉塞
//     function deleteAccountInfo(bytes32 _accountNo) public returns(bool result) {
			
// 		// 口座の有無確認
//         if(checkAccountExistence(_accountNo) == false){
//             return false ;
//         }
        
//         accountInfoList[_accountNo].delFlg = true;
        
// 		return true;
// 	}

//     // トランザクションの参照
// 	function getTransactionInfo(uint _transactionId) public constant returns(bytes32[13] transactionInfo) {
			
// 		// ユーザ情報の参照
// 		transactionInfo[0] = bytes32(transactionInfoList[_transactionId].transactionId);
// 		transactionInfo[1] = bytes32(transactionInfoList[_transactionId].transactionStatus);
// 		transactionInfo[2] = bytes32(transactionInfoList[_transactionId].transactionType);
// 		transactionInfo[3] = transactionInfoList[_transactionId].fromAccountNo;
// 		transactionInfo[4] = transactionInfoList[_transactionId].toAccountNo;
// 		transactionInfo[5] = transactionInfoList[_transactionId].fromAccountHolderName;
// 		transactionInfo[6] = transactionInfoList[_transactionId].toAccountHolderName;
// 		transactionInfo[7] = transactionInfoList[_transactionId].fromCurrency;
// 		transactionInfo[8] = transactionInfoList[_transactionId].toCurrency;
//         transactionInfo[9] = transactionInfoList[_transactionId].rate;
// 		transactionInfo[10] = bytes32(transactionInfoList[_transactionId].fromPrinc);
// 		transactionInfo[11] = bytes32(transactionInfoList[_transactionId].toPrinc);
// 		transactionInfo[12] = bytes32(transactionInfoList[_transactionId].timestamp);

//         return transactionInfo;
// 	}	

//     // 振込
// 	function transfer(uint _transactionType,bytes32 _fromAccountNo,bytes32 _toAccountNo,bytes32 _fromAccountHolderName,bytes32 _toAccountHolderName,bytes32 _fromCurrency,bytes32 _toCurrency,bytes32 _rate,uint _fromPrinc,uint _toPrinc) public returns(bool result) {
			
//         // 出金元の通貨チェック
//         if(accountInfoList[_fromAccountNo].currency != _fromCurrency){
//             return false ;            
//         }
//         // 出金元の残高チェック
//         if(accountInfoList[_fromAccountNo].balance < _fromPrinc){
//             return false ;
//         }

//         //トランザクションの登録
//         transactionCounter++;
//         transactionInfoList[transactionCounter].transactionId = transactionCounter ;
//         transactionInfoList[transactionCounter].transactionStatus = 0 ;
//         transactionInfoList[transactionCounter].transactionType = _transactionType ;

//         transactionInfoList[transactionCounter].fromAccountNo = _fromAccountNo ;
//         transactionInfoList[transactionCounter].toAccountNo = _toAccountNo ;

//         transactionInfoList[transactionCounter].fromAccountHolderName = _fromAccountHolderName ;
//         transactionInfoList[transactionCounter].toAccountHolderName = _toAccountHolderName ;

//         transactionInfoList[transactionCounter].fromCurrency = _fromCurrency ;
//         transactionInfoList[transactionCounter].toCurrency =  _toCurrency ;
//         transactionInfoList[transactionCounter].rate = _rate ;

//         transactionInfoList[transactionCounter].fromPrinc =  _fromPrinc ;
//         transactionInfoList[transactionCounter].toPrinc =  _toPrinc ;

//         transactionInfoList[transactionCounter].timestamp = block.timestamp ;        

//         //残高の増減
//         accountInfoList[_fromAccountNo].balance = accountInfoList[_fromAccountNo].balance - _fromPrinc;
//         accountInfoList[_fromAccountNo].updateTimestamp = block.timestamp;
//         accountInfoList[_toAccountNo].balance = accountInfoList[_toAccountNo].balance + _toPrinc;
//         accountInfoList[_toAccountNo].updateTimestamp = block.timestamp;
        
//         //インデックスの登録
//         userTransactionIndex[accountInfoList[_fromAccountNo].userId].push(transactionCounter);
//         if(accountInfoList[_fromAccountNo].userId != accountInfoList[_toAccountNo].userId){
//             userTransactionIndex[accountInfoList[_toAccountNo].userId].push(transactionCounter);        
//         }
        
//         return true;
// 	}
    
    
 
// // --Public関数定義 End--

// // --Private関数定義 Start--
// 	function checkUserExistence(uint _userId) private constant returns (bool result) {
// 		if (_userId != userInfoList[_userId].userId) {
// 			return false;
// 		}
// 		if (userInfoList[_userId].delFlg) {
// 			return false;
// 		}
// 		return true;
// 	}
	
// 	function checkAccountExistence(bytes32 _accountNo) private constant returns (bool result) {
// 		if (_accountNo != accountInfoList[_accountNo].accountNo) {
// 			return false;
// 		}
// 		if (accountInfoList[_accountNo].delFlg) {
// 			return false;
// 		}
// 		return true;
// 	}    
// --Private関数定義 End--
}
