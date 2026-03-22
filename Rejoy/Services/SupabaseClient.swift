import Foundation
import Supabase

enum SupabaseConfig {
    static let url = URL(string: "https://jvjsdcynjaamqfwkzpwf.supabase.co")!
    static let key = "sb_publishable_jZZVvLp7__l8rvAXhT5s4w_z0OtFbdH"
}

extension SupabaseClient {
    static let rejoy = SupabaseClient(
        supabaseURL: SupabaseConfig.url,
        supabaseKey: SupabaseConfig.key
    )
}
