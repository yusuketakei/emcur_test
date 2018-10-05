pragma solidity ^0.4.10;

contract EMCUR {

// --ストラクチャ定義 Start--
	// ユーザ情報
	struct User {
        // ユーザーアドレス
        address userAddress;
		// ユーザ名
		bytes32 userName;
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

	// 基本的な依頼情報
	struct baseRequest {
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
	    // 処理命令用ipfsハッシュ1
	    bytes32 cmdIpfsHashFirst;
	    // 処理命令用ipfsハッシュ2
	    bytes32 cmdIpfsHashSecond;
	    // ログ用ipfsハッシュ1
	    bytes32 logIpfsHashFirst;
	    // ログ用ipfsハッシュ2
	    bytes32 logIpfsHashSecond;
	}
	
	//LinkedIndexListの要素
	struct LinkedIndexlement {
	    //前の要素へのリンク(1つ目のmappingのキー)
	    uint prevElementLink ;
	    //次の要素へのリンク(mappingのキー)
	    uint nextElementLink ;
	    //インデックス
	    uint index ;
	}
	
	//LinkedIndexListのMaster
	struct LinkedIndexMaster {
	    //リストの最初の要素
	    uint firstElementKey ;
	    //リストの最後の要素
	    uint lastElementKey ;
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
    //processのステータス（実行中)
    uint constant PROC_STATUS_RUNNING=1;
    //processのステータス（済)
    uint constant PROC_STATUS_DONE=2;
    //processのステータス（エラー)
    uint constant PROC_STATUS_ERROR=9;
    //processのステータス（回復済)
    uint constant PROC_STATUS_RECOVERY=8;
    
    // --LinkedIndexListのキー--
    // UserGroupからProcessを探すインデックスのタイプ
    // 2byte type,4byte UserGroupId
    string constant INDEX_TYPE_PROCESS_BY_USERGROUP = "ug";

    // UserGroupとStatusからProcessを探すインデックスのタイプ
    // 2byte type,4byte UserGroupId,1byte status
    string constant INDEX_TYPE_PROCESS_BY_USERGROUP_STATUS = "us";
    
// --定数定義 End--

// --変数定義 Start--
    //userAddress→User
	mapping (address => User) userList;
    //requestId→RemmitanceRequest
	mapping (uint => baseRequest) baseRequestList;
    //userGroupId =>UserGroup
    mapping (uint => UserGroup) userGroupList;
    //processFlowId =>ProcessFlow
    mapping (uint => ProcessFlow) processFlowList;
    //processId=>Process
    mapping (uint => Process) processList;
        
    // --index--
    //Userが属するUserGroupId(User:UserGroup=N:1)
    mapping (address => uint) userGroupIdByUserAddressIndex;
    //UserGroupが保有するUserAddressのリスト
    mapping (uint => address[]) userAddressByUserGroupIdIndex;
    //ProcessFlowが持つProcessId群
    mapping (uint => uint[]) processIdByProcessFlowIdIndex;
    //processFlowが持つProcessNumberのステータス 添え字：processNumber 値：status
    mapping (uint => uint[]) processStatusByProcessFlowIdIndex;
    
    // インデックスを持つ汎用的なLinked List
    mapping (uint => mapping(uint => LinkedIndexlement)) linkedIndexList;
    // LinkedIndexListのMaster
    mapping (uint => LinkedIndexMaster) linkedIndexListMaster;  
    
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
        baseRequestList[requestCounter].requestId = requestCounter ;
        baseRequestList[requestCounter].requestType = _requestType ;
        baseRequestList[requestCounter].branchNo = _branchNo ;
        baseRequestList[requestCounter].accountNo = _accountNo ;
        baseRequestList[requestCounter].accountHolderName = _accountHolderName ;

        baseRequestList[requestCounter].fromCurrency = _fromCurrency ;
        baseRequestList[requestCounter].toCurrency =  _toCurrency ;
        baseRequestList[requestCounter].rate = _rate ;

        baseRequestList[requestCounter].fromAmount =  _fromAmount ;
        baseRequestList[requestCounter].toAmount =  _toAmount ;

        baseRequestList[requestCounter].applicationDate =  _applicationDate ;
        baseRequestList[requestCounter].valueDate =  _valueDate ;

        baseRequestList[requestCounter].timestamp = block.timestamp ;        

        baseRequestList[requestCounter].ipfsHashFirst =  _ipfsHashFirst ;
        baseRequestList[requestCounter].ipfsHashSecond =  _ipfsHashSeond ;
        
        //processflowの作成
        processFlowCounter++ ;
        processFlowList[processFlowCounter].processFlowId = processFlowCounter ;
        processFlowList[processFlowCounter].requestId = requestCounter ;
        
        emit remmitanceRequestLog(requestCounter,1) ;
        return true;
	}
	
	function getRemmitanceRequest(uint _requestId) public constant returns(bytes32[14] baseRequest) {

        //送金依頼の取得
        baseRequest[0] = bytes32(baseRequestList[_requestId].requestId) ;
        baseRequest[1] = bytes32(baseRequestList[_requestId].requestType) ;
        baseRequest[2] = baseRequestList[_requestId].branchNo ;
        baseRequest[3] = baseRequestList[_requestId].accountNo ;
        baseRequest[4] = baseRequestList[_requestId].accountHolderName ;
        baseRequest[5] = baseRequestList[_requestId].fromCurrency ;
        baseRequest[6] = baseRequestList[_requestId].toCurrency ;
        baseRequest[7] = bytes32(baseRequestList[_requestId].fromAmount) ;
        baseRequest[8] = bytes32(baseRequestList[_requestId].toAmount) ;
        baseRequest[9] = baseRequestList[_requestId].applicationDate ;
        baseRequest[10] = baseRequestList[_requestId].valueDate ;
        baseRequest[11] = bytes32(baseRequestList[_requestId].timestamp) ;
        baseRequest[12] = baseRequestList[_requestId].ipfsHashFirst ;
        baseRequest[13] = baseRequestList[_requestId].ipfsHashSecond ;

        return baseRequest;
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
	    processList[processCounter].cmdIpfsHashFirst = _ipfsHashFirst ;
	    processList[processCounter].cmdIpfsHashSecond = _ipfsHashSecond ;

        //processFlowとの関連付け
        processIdByProcessFlowIdIndex[_processFlowId].push(processCounter) ;
        
        //processFlowとのProcessNumberの紐付け
        processStatusByProcessFlowIdIndex[_processFlowId][_processNumber] = PROC_STATUS_WAITING ;
        
        //UserGroupId・Statusとの関連付け
        uint key1 = createLinkedListKey1ProcessByUsergroupStatus(_targetUserGroupId,PROC_STATUS_WAITING) ;
        pushLinkedIndexList(key1,processCounter,processCounter) ;

        //UserGroupIdとの関連付け（Status問わない）
        key1 = createLinkedListKey1ProcessByUsergroup(_targetUserGroupId) ;
        pushLinkedIndexList(key1,processCounter,processCounter) ;

	    return true;
	}
	// processの取得
	function getProcess(uint _processId) public constant returns (bytes32[12] returnProcess){
		returnProcess[0] = bytes32(processList[_processId].processId) ;
		returnProcess[1] = bytes32(processList[_processId].processFlowId) ;
		returnProcess[2] = bytes32(processList[_processId].processNumber) ;
		returnProcess[3] = bytes32(processList[_processId].targetUserGroupId) ;
		returnProcess[4] = bytes32(processList[_processId].status) ;
		returnProcess[5] = bytes32(processList[_processId].doneTimestamp) ;
		returnProcess[6] = bytes32(processList[_processId].doneUserId) ;
		returnProcess[7] = bytes32(processList[_processId].cmdIpfsHashFirst) ;
		returnProcess[8] = bytes32(processList[_processId].cmdIpfsHashSecond) ;
		returnProcess[7] = bytes32(processList[_processId].logIpfsHashFirst) ;
		returnProcess[8] = bytes32(processList[_processId].logIpfsHashSecond) ;

		return returnProcess ;
	}
	
	// processのStatus更新
	function _updateProcessStatus(uint _processId,uint _nextStatus) public constant returns (bool){
	    //Processの現在のステータスを取得
	    uint currentStatus = processList[_processId].status ;
	
		//該当ステータスに更新できるかチェック
	    //Waiting>Running>Done or Error>Recovery
	    //waiting->Runnning
	    if(currentStatus == PROC_STATUS_WAITING){
	        //次のステータスは"実行中"
	        require(_nextStatus == PROC_STATUS_RUNNING) ;
	        //実行可能状態
	        require(isExecutableProcess(_processId)) ;
	    }else if(currentStatus == PROC_STATUS_RUNNING){
	        require(_nextStatus == PROC_STATUS_DONE || _nextStatus == PROC_STATUS_ERROR) ;
	    }else if(currentStatus == PROC_STATUS_ERROR){
	        require(_nextStatus == PROC_STATUS_RECOVERY) ;
	    }
	
		return true ;
	
	}

	//LinkedListの1つ目のKeyにあたるハッシュ値を生成
	function createLinkedListKey1(bytes32 _sourceStr1,bytes32 _sourceStr2,bytes32 _sourceStr3,bytes32 _sourceStr4) public constant returns (uint){
	    return uint(keccak256(_sourceStr1,_sourceStr2,_sourceStr3,_sourceStr4)) ;        
	}
	
	//UserGroupとStatusからProcessを探すインデックスのKey1を生成
	function createLinkedListKey1ProcessByUsergroupStatus(uint _userGroupId,uint _status) public constant returns (uint){
	    return uint(keccak256(INDEX_TYPE_PROCESS_BY_USERGROUP_STATUS,bytes4(_userGroupId),bytes1(_status),"")) ;        
	}
	
	//UserGroupとStatusからProcessを探すインデックスのKey1を生成
	function createLinkedListKey1ProcessByUsergroup(uint _userGroupId) public constant returns (uint){
	    return uint(keccak256(INDEX_TYPE_PROCESS_BY_USERGROUP,bytes4(_userGroupId),"","")) ;        
	}


	//LinkedIndexListへのアクセス 全件の取得
	function getLinkedIndexListElements(uint _key1) public constant returns(uint[] resultIndexList){
        //最初の要素から取得
        uint currentElementKey ;
        currentElementKey = linkedIndexListMaster[_key1].firstElementKey ;
	  
	    //一度に返す要素数分LinkedListから結果リストに格納
	    for(uint i = 0; i < resultIndexList.length ;i++){
	        resultIndexList[i] = linkedIndexList[_key1][currentElementKey].index ;
	        currentElementKey = linkedIndexList[_key1][currentElementKey].nextElementLink ;
	    }
	}
	//LinkedIndexListへのアクセス nextKey2:ページングなどリストを続きから取得する場合に前回の最後の要素
	function getLinkedIndexListElementsWithPaging(uint _key1,uint _lastKey2) public constant returns(uint[10] resultIndexList,uint lastKey2){
	    // 最初に取得する要素を取得
	    uint currentElementKey ;
	    if(_lastKey2 == 0){
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
	function pushLinkedIndexList(uint _key1,uint _key2,uint _index) public returns(bool){
	    //対象のIndexListのマスターから最後の要素を取得
	    uint lastElementKey = linkedIndexListMaster[_key1].lastElementKey;
	    
	    //今回が最初の要素の場合、最初の要素を更新
	    if(linkedIndexListMaster[_key1].firstElementKey == 0){
	        linkedIndexListMaster[_key1].firstElementKey = _key2 ;
	    }else{
	        //最初の要素じゃない場合、前の要素を更新
	        linkedIndexList[_key1][lastElementKey].nextElementLink = _key2 ;
	    }
	    
	    //要素を追加
	    linkedIndexList[_key1][_key2].prevElementLink = lastElementKey ;
	    linkedIndexList[_key1][_key2].nextElementLink = 0 ;
	    linkedIndexList[_key1][_key2].index = _index;
	    
	    //最後の要素を更新
	    linkedIndexListMaster[_key1].lastElementKey = _key2 ;
	    
	    return true ;
	    
	}
	function removeLinkedIndexList(uint _key1,uint _key2) public returns(bool){
	    //対象のIndexListの前後のリンクを付け替える
	    uint prevElementLink = linkedIndexList[_key1][_key2].prevElementLink;
	    uint nextElementLink = linkedIndexList[_key1][_key2].nextElementLink;

        //削除対象の要素が最初の要素の場合
        if(linkedIndexListMaster[_key1].firstElementKey == _key2){
            //次の要素があれば、最初の要素を更新する
            if(nextElementLink == 0){
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
            if(prevElementLink == 0){
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
	//自分が所属するUserGroupが持つ処理待ちのプロセスの一覧を取得
	function getMyWatingProcessList() public constant returns(uint[] resultProcessIdList){
	    uint userGroupId = userGroupIdByUserAddressIndex[msg.sender] ;
	    return _getProcessListByUserGroupIdStatus(userGroupId,PROC_STATUS_WAITING) ;
	}
	function _getProcessListByUserGroupIdStatus(uint _userGroupId,uint _status) private constant returns(uint[] resultProcessIdList){
	    uint key1 = createLinkedListKey1ProcessByUsergroupStatus(_userGroupId,_status) ;
	    return getLinkedIndexListElements(key1) ;
	}
	//processがが実行可能か確認
	function isExecutableProcess(uint _processId) public constant returns (bool isExecutableFlg){
	    //このプロセスの前提となるプロセスのProcessNumberを取得
	    uint[MAX_PREV_PROCESS_NUM] memory prevProcessNumberList = processList[_processId].prevProcessNumber ;
	    
	    //前提となるプロセスが完了しているか確認
	    uint processFlowId = processList[_processId].processFlowId ;
        uint[] memory processStatusList = processStatusByProcessFlowIdIndex[processFlowId] ;

        for(uint i=1;i<prevProcessNumberList.length;i++){
            uint targetProcessNumber = prevProcessNumberList[i] ;
            if(processStatusList[targetProcessNumber] != PROC_STATUS_DONE){
                return false ;
            }
        }
        return true ;
	}
}
