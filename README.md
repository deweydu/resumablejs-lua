## Resumable.js sample server implementation in Lua

This is the implementation of the server side part of Resumable.js client script, which sends/uploads files to a server in several chunks.

#### Install Dependencies

* OpenResty http://openresty.org

* This is a fork of luafilesystem, which we added the chmod function to enhance the system security. 

    1. $ cd lib/luafilesystem; 
    2. $ vi config // edit LUA_INC directory
    3. $ make // run make to create lfs.so
    4. $ cp src/lfs.so /yourlualibpath // make sure your lua script can find the lfs.so    


* Resumable.js http://www.resumablejs.com/
* Make sure MEDIA folder and TEMP folder exists. We use /yourpath/media/ & /yourpath/temp/ by default. You can change it to wherever you want.




