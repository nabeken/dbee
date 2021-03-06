=======================
DbeE リクエスト管理仕様
=======================

DbeEではエンコードに必要なジョブをリクエストという単位で扱う。
エンコードを依頼するものはエンコードに必要な情報、エンコード後の後処理に必要な情報をまとめて
リクエスト用のAPIへデータをPOSTする。

リクエストが成功するとリクエストを追跡できるリクエストIDが返却される。
このリクエストIDを使ってこのリクエストがどのジョブを実行中かを追跡することができる。

ジョブはリクエスト内で重複しないものとする。同じジョブ名を使った場合の動作は不定。

次のジョブがなければそのジョブでリクエストは完了。

リクエスト管理で使うデータ
==========================

リクエストIDの管理
    リクエスト間で一意なID (なんかのハッシュ値でもいいとは思う)

各リクエストの情報管理

  - running_jobの管理  (実行中のジョブ)
  - run_listの管理     (これから実行するジョブ)
  - ran_listの管理     (実行したジョブ)
  - run_argsの管理     (各ジョブに対する引数)
  - workerの管理       (ジョブを実行しているホスト名)
  - last_updatedの管理 (リクエストが更新された最終時刻)

リクエストAPIの流れ
===================

0. リクエスト前にどのエンコードオプションでリクエストするか調べる (APIはまだない)

   ここでどのレベルでエンコードするか調べる(保存用なのかiPad用なのか、など)。
   現状はすべてiPad向けの設定とする。

   エンコードオプションはシリアライズして返す？

1. リクエストをするノードは以下のJSONをPOSTする。

    Request APIに投げるJSON ::

        {
          "requester": リクエストをしたホスト名,
          "material_node": 素材を保持しているノード
          "run_list": [
            {
              "name": class1,
              "args": 引数
            },
            {
              "name": class2,
              "args": 引数
            }
          ],
          "program" {
            "name": 番組名,
            "ch": チャネル名,
            "filename": 素材のファイル名
          }
        }

2. リクエストをPOSTで受けとったRequest APIはまず素材ファイルのメタデータを生成するジョブ(DBEE::Job::GenerateMetadata)を
   run_listへ追加し "material_node_${hostname}" キューへenqueueする。

   具体的には:

   a) 以下のJSONをファイル名.jsonで生成する ::

      {
        "filename": "filename.ts",
        "size": filesize,
        "SHA256": SHA256,
        "mtime": mtime,
        "ctime": ctime
      }

3. リクエストをPOSTで受け取ったRequest APIはrun_listに基づいてジョブをenqueueする。

   具体的には:

   a) run_listをshiftし先頭のクラス名を取得。
   b) Resque.enqueue(クラス名, request_id, output)でエンキューする。

3. Request APIへジョブの開始を通知する。

   具体的には:

   a) running_jobを現在のクラス名でPUT
   b) workerを現在のworkerのホスト名でPUT

4. ジョブを開始する前にRequest APIから引数のrequest_id, outputの情報を取得する。

   具体的には:

   a) Request APIからrequest_idの情報を取得。
   b) output["file"] から出力先の情報を取得する。
   c) 直前のジョブの成果物を利用してジョブ実行。

5. ジョブが完了するとworkerはRequest APIを叩く。

   具体的には:

   a) 先程取得したrequest["run_list"][class]["output"]["file"](ジョブ固有)に成果物の場所を記録する。
   b) 次のジョブも同じノードで実行する必要がある場合は
      先程取得したrequest["run_list"]["output"]["same_node"]をtrueに、そうでなければfalseを設定する。
   c) requestをPUTする。
   d) running_jobをDELETEする。

6. ジョブが失敗するとworkerはRequest APIを叩く。

   具体的には:

   a) 先程取得したrequestのrunning_jobをnullに設定し、PUTする。nullにすることでジョブが失敗したことを通知する。
   b) 特にステータスが変わるわではなくて単にジョブがDELETEされないのでこれ以上進まないだけ。
      running_jobがnullであれば失敗して止まっていると区別するため。

7. running_jobのDELETEを受け取ったRequest APIはrun_listに基づいてジョブをenqueueする。

   具体的には:

   a) requestのran_listにrunning_jobをpushする。
   b) requestのrun_listからrunning_jobを削除する。

8. running_jobがnullのPUTを受け取ったRequest APIはそのリクエストを中断する。

Redis上の扱い
=============

- リクエストIDの管理

  - key resque:request_id
  - hkey resque:request

- 各リクエストの情報管理

  - running_jobの管理  (実行中のジョブ)
  - run_listの管理 (これから実行するジョブ)
  - ran_listの管理 (実行したジョブ)
  - run_argsの管理 (各ジョブに対する引数)
  - workerの管理   (ジョブを実行しているホスト名)
