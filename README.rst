===============================================
DBEE - A Distributed Batch Encoding Environment
===============================================

REQUIREMENT
===========

- Ruby 1.9+
- ffmpeg with x264
- Redis (used by resque)
- stunnel to tunnel redis connection securely (if you want to distribute jobs across the internet)
- Web server to serve materials (Nginx, lighttpd, Apache, etc...)
- Amazon S3 or Swift to store outputs

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

4. Sign up Amazon S3 or Setup swift

5. Copy config.rb.sample to config.rb and Edit ::

    $ config.rb.sample config.rb
    $ vi config.rb

6. Start API server. ::

    $ thin --address 127.0.0.1 --port 9393 --rackup config.ru start

7. Start workers. ::

    $ god -c god/all-in-one.god

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

- iPad/iPhone/Android App (using Titanium Mobile)
- EC2 integration
