//
//  ChatRoom.swift
//  FireAlarm
//
//  Created by NobodyNada on 8/27/16.
//  Copyright © 2016 NobodyNada. All rights reserved.
//

import Foundation

protocol ChatRoomDelegate {
    func chatRoomMessage(_ room: ChatRoom, message: ChatMessage, isEdit: Bool)
}

class ChatRoom: NSObject, WebSocketDelegate {
    enum ChatEvent: Int {
        case messagePosted = 1
        case messageEdited = 2
        case userEntered = 3
        case userLeft = 4
        case roomNameChanged = 5
        case messageStarred = 6
        case debugMessage = 7
        case userMentioned = 8
        case messageFlagged = 9
        case messageDeleted = 10
        case fileAdded = 11
        case moderatorFlag = 12
        case userSettingsChanged = 13
        case globalNotification = 14
        case accessLevelChanged = 15
        case userNotification = 16
        case invitation = 17
        case messageReply = 18
        case messageMovedOut = 19
        case messageMovedIn = 20
        case timeBreak = 21
        case feedTicker = 22
        case userSuspended = 29
        case userMerged = 30
        case usernameChanged = 34
    };
    
    
    
    let client: Client
    let roomID: Int
    
    var delegate: ChatRoomDelegate?
    
    fileprivate var pendingLookup = [ChatUser]()
    
    var userDB = [ChatUser]()
    
    func lookupUserInformation() {
        do {
            print("Looking up \(pendingLookup.count) user\(pendingLookup.count == 1 ? "" : "s")...")
            let ids = pendingLookup.map {user in
                String(user.id)
            }
            
            let json: String = try client.post(
                "https://chat.\(client.host.rawValue)/user/info",
                [
                    "ids" : ids.joined(separator: ","),
                    "roomID" : "1"
                ]
            )
            
            guard let results = try client.parseJSON(json) as? NSDictionary else {
                throw EventError.jsonParsingFailed(json: json)
            }
            
            guard let users = results["users"] as? NSArray else {
                throw EventError.jsonParsingFailed(json: json)
            }
            
            for obj in users {
                guard let user = obj as? NSDictionary else {
                    throw EventError.jsonParsingFailed(json: json)
                }
                
                guard let id = user["id"] as? Int else {
                    throw EventError.jsonParsingFailed(json: json)
                }
                guard let name = user["name"] as? String else {
                    throw EventError.jsonParsingFailed(json: json)
                }
                
                let isMod = (user["is_moderator"] as? Bool) ?? false
                
                //if user["is_owner"] is an NSNull, the user is NOT an owner.
                let isRO = (user["is_owner"] as? NSNull) == nil ? true : false
                
                let chatUser = userWithID(id)
                chatUser.name = name
                chatUser.isMod = isMod
                chatUser.isRO = isRO
            }
            pendingLookup.removeAll()
        }
        catch {
            handleError(error, "while looking up \(pendingLookup)")
        }
    }
    
    ///Looks up a user by ID.  If the user is not in the database, they are added.
    func userWithID(_ id: Int) -> ChatUser {
        for user in userDB {
            if user.id == id {
                return user
            }
        }
        let user = ChatUser(room: self, id: id)
        userDB.append(user)
        if id == 0 {
            user.name = "Console"
        }
        else {
            pendingLookup.append(user)
        }
        return user
    }
    
    
    ///Looks up a user by name.  The user must already exist in the database!
    func userNamed(_ name: String) -> [ChatUser] {
        var users = [ChatUser]()
        for user in userDB {
            if user.name == name {
                users.append(user)
            }
        }
        return users
    }
    
    
    func loadUserDB() throws {
        guard let data = try? Data(contentsOf: saveFileNamed("users.json")) else {
            return
        }
        guard let db = try JSONSerialization.jsonObject(with: data, options: []) as? NSArray else {
            return
        }
        
        userDB = []
        var users = userDB
        
        for item in db {
            guard let id = (item as? NSDictionary)?["id"] as? Int else {
                continue
            }
            users.append(userWithID(id))
        }
        
        userDB = users
    }
    
    func saveUserDB() throws {
        let db = userDB.map {["id":$0.id]}
        let data = try JSONSerialization.data(withJSONObject: db, options: .prettyPrinted)
        try? data.write(to: saveFileNamed("users.json"), options: [.atomic])
    }
    
    
    
    var ws: WebSocket!
    fileprivate var wsRetries = 0
    fileprivate let wsMaxRetries = 10
    
    var inRoom = false
    
    var timestamp: Int = 0
    
    var messageQueue = [String]()
    
    init(client: Client, roomID: Int) {
        self.client = client
        self.roomID = roomID
    }
    
    enum RoomJoinError: Error {
        case roomInfoRetrievalFailed
    }
    
    fileprivate func connectWS() throws {
        //get the timestamp
        guard let time = (try client.parseJSON(client.post("https://chat.\(client.host.rawValue)/chats/\(roomID)/events", [
            "roomid" : roomID,
            "fkey": client.fkey
            ])) as? NSDictionary)?["time"] as? Int else {
                throw RoomJoinError.roomInfoRetrievalFailed
        }
        timestamp = time
        
        //get the auth code
        let wsAuth = try client.parseJSON(
            client.post("https://chat.\(client.host.rawValue)/ws-auth", ["roomid":roomID, "fkey":client.fkey]
            )
            ) as! NSDictionary
        
        let wsURL = wsAuth["url"] as! String
        
        var request = URLRequest(url: URL(string: "\(wsURL)?l=\(timestamp)")!)
        
        request.setValue("https://chat.\(client.host.rawValue)", forHTTPHeaderField: "Origin")
        
        ws = WebSocket(request: request)
        ws.eventQueue = client.queue
        ws.delegate = self
    }
    
    fileprivate func messageQueueHandler() {
        while messageQueue.count != 0 {
            var result: String? = nil
            do {
                result = try client.post(
                    "https://chat.\(client.host.rawValue)/chats/\(roomID)/messages/new",
                    ["text":messageQueue[0], "fkey":client.fkey]
                )
            }
            catch {
                handleError(error)
            }
            do {
                if let json = result {
                    let _ = try client.parseJSON(json)
                    messageQueue.removeFirst()
                }
            }
            catch {
                if let r = result {
                    print(r)
                }
                else {
                    handleError(error)
                }
            }
            sleep(1)
        }
    }
    
    func postMessage(_ message: String) {
        messageQueue.append(message)
        if messageQueue.count == 1 {
            client.queue.async {
                self.messageQueueHandler()
            }
        }
    }
    
    func postReply(_ reply: String, to: ChatMessage) {
        if let id = to.id {
            postMessage(":\(id) \(reply)")
        }
        else {
            postMessage("@\(to.user) \(reply)")
        }
    }
    
    func join() throws {
        print("Joining chat room \(roomID)...")
        
        try connectWS()
        
        let _ = userWithID(0)   //add the Console to the database
        let json: String = try client.get("https://chat.\(client.host.rawValue)/rooms/pingable/\(roomID)")
        guard let users = try client.parseJSON(json) as? NSArray else {
            throw EventError.jsonParsingFailed(json: json)
        }
        
        for userObj in users {
            guard let user = userObj as? NSArray else {
                throw EventError.jsonParsingFailed(json: json)
            }
            guard let userID = user[0] as? Int else {
                throw EventError.jsonParsingFailed(json: json)
            }
            let _ = userWithID(userID)
        }
        
        print("Users in database: \((userDB.map {$0.description}).joined(separator: ", "))")
        
        inRoom = true
        
    }
    
    func leave() {
        //we don't really care if this fails
        //...right?
        inRoom = false
        let _ = try? client.post("https://chat.\(client.host.rawValue)/chats/leave/\(roomID)", ["quiet":"true","fkey":client.fkey]) as String
        ws.close()
        while ws.readyState == .closing {
            sleep(1)
        }
    }
    
    enum EventError: Error {
        case jsonParsingFailed(json: String)
        case invalidEventType(type: Int)
    }
    
    func handleEvents(_ events: NSArray) throws {
        for e in events {
            guard let event = e as? NSDictionary else {
                throw EventError.jsonParsingFailed(json: String(describing: events))
            }
            guard let typeCode = event["event_type"] as? Int else {
                throw EventError.jsonParsingFailed(json: String(describing: events))
            }
            guard let type = ChatEvent(rawValue: typeCode) else {
                throw EventError.invalidEventType(type: typeCode)
            }
            
            switch type {
            case .messagePosted, .messageEdited:
                guard
                    let userID = event["user_id"] as? Int,
                    let messageID = event["message_id"] as? Int,
                    let content = event["content"] as? String else {
                        throw EventError.jsonParsingFailed(json: String(describing: events))
                }
                
                //look up the user instead of getting their name to make sure they're in the DB
                let user = userWithID(userID)
                
                print("\(user): \(content)")
                
                let message = ChatMessage(user: user, content: content, id: messageID)
                if let d = delegate {
                    d.chatRoomMessage(self, message: message, isEdit: type == .messageEdited)
                }
            default:
                break
            }
        }
    }
    
    func webSocketOpen() {
        print("Websocket opened!")
        wsRetries = 0
    }
    
    func webSocketClose(_ code: Int, reason: String, wasClean: Bool) {
        //do nothing -- we'll handle this in webSocketEnd
    }
    
    func webSocketError(_ error: NSError) {
        //do nothing -- we'll handle this in webSocketEnd
    }
    
    @objc func webSocketMessageText(_ text: String) {
        do {
            guard let json = try client.parseJSON(text) as? NSDictionary else {
                throw EventError.jsonParsingFailed(json: text)
            }
            
            let roomKey = "r\(roomID)"
            guard let events = (json[roomKey] as? NSDictionary)?["e"] as? NSArray else {
                return  //no events
            }
            
            try handleEvents(events)
        }
        catch {
            handleError(error, "while parsing events")
        }
    }
    
    @objc func webSocketMessageData(_ data: Data) {
        print("Recieved binary data: \(data)")
    }
    
    func webSocketEnd(_ code: Int, reason: String, wasClean: Bool, error: NSError?) {
        if let e = error {
            print("Websocket error:\n\(e)")
        }
        else {
            print("Websocket closed")
        }
        
        if inRoom {
            if wsRetries >= wsMaxRetries {
                fatalError("Failed to reconnect websocket!")
            }
            print("Trying to reconnect...")
            webSocketOpen()
        }
    }
    
}