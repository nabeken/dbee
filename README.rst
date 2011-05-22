===============================================
DBEE - A Distributed Batch Encoding Environment
===============================================

REQUIREMENT
===========

- Ruby 1.9+
- ffmpeg with x264
- TsSplitter.exe to splite MPEG2 TS to avoid some audio channel problems
- wine to run TsSplitter.exe on Linux/FreeBSD
- patched faad frontend to detect audio channel settings
- Redis (used by resque)
- stunnel to tunnel redis connection securely (if you want to distribute jobs across the internet)
- Web server to serve materials (Nginx, lighttpd, Apache, etc...)
- Object Storage or WebDAV-based storage such as Amazon S3, Swift or mod_dav(Apache2)

INSTALL
=======

Use bundle to install dependencies. ::

    $ git clone git://github.com/nabeken/dbee.git
    $ cd dbee
    $ bundle
    $ git submodule init

Getting started
===============

1. Setup redis

2. Setup Web server

3. Build ffmpeg with x264

4. Build wine

5. Build patched faad

4. Sign up Amazon S3 or Setup swift

5. Copy config.rb.sample to config.rb and Edit ::

    $ config.rb.sample config.rb
    $ vi config.rb

6. Start API server. ::

    $ god -c god/thin.god

7. Start workers. ::

    $ god load god/all-in-one.god

8. Enqueue it! ::

    $ ruby bin/dbee-enqueuer.rb homuhomu.ts

ARCHTECTURE
===========

- Resque
- JSON API
- Amazon S3 or Swift

::

                       +-----+         +--------+         +-------+
                       | API |---------| Resque |---------| Redis |
                       +-----+         +--------+         +-------+
                          |                                   |
                          |            +--------+             |
                          +------------| Worker |-------------+
         +-------------+  |            +--------+             |   +----------+
         |             |  +------------| Worker |-------------+   |          |
         |             |  |            +--------+             |   |          |   +---------------------+
         | Web server  |--+------------| Worker |-------------+---| S3/Swift |---| iPad/iPhone/Android |
         |             |  |            +--------+             |   |          |   +---------------------+
         |             |  +------------| Worker |-------------+   |          |
         +-------------+  |            +--------+             |   +----------+
                          +------------| Worker |-------------+
                                       +--------+

FUTURE WORK
===========

- TVRock integration
- iPad/iPhone/Android App (using Titanium Mobile)
- EC2 integration
