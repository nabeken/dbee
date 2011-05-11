.. DbeE documentation master file, created by
   sphinx-quickstart on Sat Apr 16 01:30:36 2011.
   You can adapt this file completely to your liking, but it should at least
   contain the root `toctree` directive.

Welcome to DbeE's documentation!
================================

.. toctree::

   README
   job
   api
   request

用語の定義
==========

master node (1つ)
    Redisが動作しているノード。
    ``material_node`` のうちの1つが担当。

material node (複数)
    素材を保持しているノード

storage node (複数)
    成果物を保持しているノード。通常はS3互換環境。

worker (複数)
    素材をmaterialノードからダウンロードし、エンコードし、成果物をstorageノードへアップロードするノード

master nodeとworker間のredisについて
------------------------------------

master nodeのredisはローカルIPアドレスで接続を受け付ける。しかし、別ネットワークのworkerもredisへ接続する必要がある。
そこで、master nodeとworkerの両端をstunnelで終端し、SSL上でredisの通信をトンネルすることにする。
別ネットワーク内にも複数のマシンがある場合は、そのうちの1台がstunnelを動かせばよい。stunnel4はIPv6対応。 ::

           LAN
    +----------------+
    |                |
    |  +----------+  |
    |  | master   |  |     server mode                   client mode
    |  |          |  |     +---------+     over SSL      +---------+     +--------+
    |  |  redis   |--------| stunnel |-------------------| stunnel |-----| worker |
    |  |(tcp/6379)|  |     +---------+                   +---------+     +--------+
    |  +-----|---+   |     (tcp/16379)                    (tcp/6379)
    |        |       |
    |   +--------+   |
    |   | worker |   |
    |   +--------+   |
    +----------------+
