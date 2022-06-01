//	
// Copyright © Essential Developer. All rights reserved.
//

import Foundation

//Null object pattern
//an instance sharing a same interface but does nothing!

class NullFriendsCache: FriendsCache {
    override func loadFriends(completion: @escaping (Result<[Friend], Error>) -> Void) {}
}
