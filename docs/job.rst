===============
DbeE ジョブ仕様
===============

.. _Resque: https://github.com/defunkt/resque
.. _Redis: http://redis.io/

DbeEではジョブ管理に Resque_ を使用している。そしてResqueは Redis_ を使用している。

workerは直接Redisサーバと通信できる必要がある。
ジョブの投入は一部ジョブはRESTful API経由でラップしてResqueへ投入する。

ジョブは1つでは完結せず、次に実行すべきジョブの情報を含めて実行されることがある。
ジョブは自身の成果物を見て、次のジョブも前のジョブと同じノードで実行される必要が
あるかどうか判断する。もし、必要があればそのためのフラグを立てる。

フラグを立てた後、インスタンス変数 @host_based_queue に自身のホスト名を入れる。

各workerは自身のキューを必ず持つ。同一workerで実行すべきタスクは各worker専用
のキューへ投入する。

流れ
====

ジョブの入口はエンコードの依頼(request)から始まる。依頼の前提:

- 依頼者は素材動画がworkerからアクセス可能なURLを自身で生成できる

依頼にはいくつかの情報を含める必要がある。

- 素材動画のダウンロード方法と場所
- エンコーダーの情報
- エンコーダーの設定
- 成果物のアップロード方法と場所
- 公開処理の情報
- 通知処理の情報
- 素材処理の情報

ジョブの種類
============

workerが担当 (分散する)

    * 素材のダウンロードジョブ
    * 動画のエンコードジョブ (ジョブが完了すると自身のキューにアップロードジョブを投入する)

      * 動画の場所
      * 動画のメタデータ
      * キュー先
      * エンコーダーバックエンド
      * エンコードプロファイル

    * 成果物のアップロードジョブ (ジョブが完了するとmasterのキューに公開処理ジョブを投入する)

masterが担当 (分散しない)

    * 公開処理ジョブ (当面は以下3つのジョブは1つのジョブとして扱う)
    * 通知処理ジョブ
    * 素材の処理(削除、移動など)

ジョブのクラス名
================

引数はRequest API経由で取得する。

- DBEE::Job::GenerateMetadata (このジョブは通常、Request API側で自動的に挿入される)

  キュー初期値
    material_node_${hostname}

  引数
    なし

  出力
    なし (JSONをファイルへ出力するだけ)

- DBEE::Job::Download (今のところhttpのみ)

  キュー初期値
    all_worker

  引数
    認証情報とダウンロード先のベースURL

  出力
    保存先 => output["file"]

- DBEE::Job::Encode (今のところffmpegのみ)

  キュー初期値
    all_worker

  引数
    ffmpeg用の設定、素材の保存先

  出力
    エンコードされた動画の保存先 => output["file"]

- DBEE::Job::Upload (今のところS3クローンのみ)

  キュー初期値
    all_worker

  引数
    認証情報とアップロード先、成果物の保存先

  出力
    成果物のアップロード先 => output["url"]

- DBEE::Job::Notification     (今のところメールを送るのみ)

  キュー初期値
    master

  引数
    メールサーバ情報、メールアドレス、成果物のアップロード先

- DBEE::Job::PostProcess      (今のところ何もしない)

  キュー初期値
    material_node_${hostname}

  引数
    何もしない

ジョブ間のインターフェース
==========================

各ジョブは他のジョブの成果物を使い成果物を出力する。
そのため、1つ前のジョブの成果物の所在を得る必要がある。また、自身の成果物の所在を次のジョブへ通知
する必要がある。

ジョブが完了するとoutput(ハッシュ)に成果物についての情報を格納する。

Resqueからは以下のようにして引数を渡す。 ::

    Resque.enqueue(DBEE::Job::Encode, request_id, next_job_name, args)

ここで ``args`` は ``run_list`` の ``args`` と1つ前のジョブの ``output`` をマージしたものである。 ::

  next_job["args"].merge!(output)

したがって、outputが優先される。

Resqueはenqueue時に第1引数のインスタンス変数 @queue もしくは特異メソッド queue を呼びだす。
ホスト名を指定してenqueueする場合は以下を実装する。 ::

    attr_accessor :hostbased_queue
    
    def self.queue
      @host_based_queue || :encode
    end

そして ``Resque.enqueue`` 前に ``DBEE::Job::Encode.instance_variable_set(:@host_based_queue, Factor.fqdn)`` をする。

キュー
======

重い処理には専用のキューを割当てる。

1. メタデータ生成
2. ダウンロード
3. エンコード
4. アップロード

軽い通知には共通のキューを割当てる。

1. 通知処理
2. 後処理

master node用キュー
-------------------

キュー名: ``master``

master nodeで処理する必要のあるジョブはこのキューへ投入する。

material node用キュー
---------------------

キュー名: ``material_node_${hostname}``

materialに対して操作する必要のあるジョブはこのキューへ投入する。

全worker用キュー
----------------

キュー名: ``all_worker``

分散可能なジョブはこのキューへ投入する。

worker用キュー
--------------

キュー名: ``${prefix}_worker_${hostname}``

- download_worker_${hostname}
- encode_worker_${hostname}
- upload_worker_${hostname}

別々のジョブを同じworkerで処理する必要のあるジョブはこのキューへ投入する。

workerの数はマシン性能によって決める。一般にencode workerは4コア以下は1つが望ましい。
