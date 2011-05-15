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

MPEG2 TSの音声切り替え問題について
----------------------------------

.. _`faad_frontend_main_return.patch`: https://github.com/nabeken/dbee/blob/master/sample/faad_frontend_main_return.patch

MPEG2 TSの音声でしばしば音声の切り替え(モノラルからステレオ、またはその逆)が発生する。
このことに無頓着なエンコーダ、デコーダを使った場合多くは切り替え後無音となることになる。

VLCなどでの再生時は音声チャネルを一度無効にし、再度有効にすると音声が出力されるようになる。
しかし、ffmpegでのエンコード中は対処のしようがない。今回はWindowsのアプリケーションである
``TsSplitter`` を使い、音声の切り替え時にTSを分割するようにした(言うまでもないが、FreeBSD, Linux
上で動かす場合はWineを通す)。

TSファイルから音声だけを抜き取り、音声切り替えが起きている場合のみ分割することにした。
音声切り替えの検出は抜き取ったAACに対して ``faad`` コマンドを通し、終了コードを見て検出している。

ただし、通常の ``faad`` コマンドはAACファイルのエラーを検出して、エラー終了しても終了コードが常に
``0`` となってしまう。ここでは `faad_frontend_main_return.patch`_ パッチを当ててエラー終了時
はその時のエラーコードをそのまま終了コードとして返すようにしている。

実際の処理は ``DBEE::Job::GenerateMetadata`` を参照のこと。
