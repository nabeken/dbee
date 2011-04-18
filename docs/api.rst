============
DbeE API仕様
============

DbeEでは認証、バージョンは意識しない。上位のプロキシで認証およびバージョンによる振り分けを行なう。

RESTful APIを目指す。

API概要
=======

APIは4つのコンポーネントから構成される。

DbeE Webインターフェース
    DbeE自身の設定や自身のRESTful APIを使った管理画面を提供する。

DbeE リクエスト管理API
    DbeEの分散バッチエンコードリクエストを管理するためのRESTful APIを提供する。

DbeE キュー管理API
    Resqueへのジョブ投入、ジョブ修正、ジョブ削除、ジョブ一覧取得用のRESTful APIを提供する。

DbeE materials API
    素材動画のダウンロード用のRESTful APIを提供する。

RESTful APIはすべてJSON形式で情報を交換する。

DBEE::App
=========

DbeE Webインターフェースを提供する。

DBEE::App::Request
==================

DbeEの分散バッチエンコードリクエストを管理するためのRESTful API。

一応、コンフリクトしないようにレスポンス毎にハッシュ値を入れておく。

公開リソース
------------

* /request/

  POST
    リクエスト内容に応じて新規リクエストを生成し、run_listに沿ってResque.enqueueする。
  GET
    これまでの全リクエストのリストを返す。

* /request/:id

  GET
    リクエスト情報を返す
  PUT
    リクエストを更新する

* /request/:id/running_job

  - running_jobを削除するとジョブが完了したと判断して次のrun_listからenqueueする。
  - running_jobがnullに設定されるとジョブが失敗したと判断してリクエストの処理を中断する。

  GET
    running_jobを返す。

  PUT
    running_jobを設定する。

  DELETE
    running_jobを削除する。 (DELETEが成功するのは最初の1度だけなので2度実行されても問題ない)

    また、ran_listに削除前のrunnin_jobがない、かつrun_listに削除前のrunning_jobがあればジョブは実行中なので削除はしない。

* /request/:id/worker

  GET
    workerを返す。

  PUT
    workerを設定する。

* /request/:id/run_list/[:class]

  GET
    run_listを返す。あるいはclassのデータを返す。

  PUT
    run_listを設定する(GETしたものを操作してPUT)。 (RESTfulなのでPUTを何度叩いても大丈夫にしなければならない)

* /request/:id/ran_list/

  GET
    ran_listを返す。

  PUT
    ran_listを設定する(GETしたものを操作してPUT)。

DBEE::App::Job
==============

ジョブ管理のためのRESTful API。

ジョブ実行に必要な詳細情報はジョブ実行時にRequest APIから取得する。

公開リソース
------------

* /job/

  * GET: すべてのジョブ返す

* /job/:queue_name

  * POST: ジョブを:queue_nameキューにエンキューする

* /job/:queue_name/:id

  * GET: キューに入っているジョブの情報を返す
  * PUT: キューに入っているジョブの情報を更新する
  * DELETE: キューに入っているジョブを削除する

* /job/failed/[:queue_name]

  * GET: これまでに失敗したジョブのリストを返す

* /job/working/[:queue_name]

  * GET: 現在処理中のジョブのリストを返す

* /job/queued/[:queue_name]

  * GET: 現在キューに入っているジョブを返す
