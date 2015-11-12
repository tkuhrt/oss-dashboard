# Copyright 2015 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require "sqlite3"

def loadUserTable(db, users)
  db.execute("BEGIN TRANSACTION");
  db.execute("DELETE FROM users")
  users.each do |login, email|
      db.execute(
       "INSERT INTO users (
          login, email
        )
        VALUES ( ?, ? )",
        [ login, email ] )
  end
  db.execute("END TRANSACTION");
end

def sync_user_mapping(feedback, dashboard_config, client, sync_db)

  # both should be executed and provides USER_EMAILS
  # TODO: It should be executed _after_ the user emails are loaded, ie) there should be a function to call
  map_user_script=dashboard_config['map-user-script']
  if(map_user_script)
    if(File.exist?(map_user_script))
      require(map_user_script)
      loadUserTable(sync_db, USER_EMAILS)
    else
      puts "User mapping script not found: #{map_user_script}"
    end
  end
end

