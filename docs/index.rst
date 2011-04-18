.. DbeE documentation master file, created by
   sphinx-quickstart on Sat Apr 16 01:30:36 2011.
   You can adapt this file completely to your liking, but it should at least
   contain the root `toctree` directive.

Welcome to DbeE's documentation!
================================

.. toctree::

   job
   api
   request

用語の定義
==========

master (1つ)
    Redisが動作しているノード。エンコード後の後処理を担当するノード。

materials (複数)
    素材を保持しているノード

storage (複数)
    成果物を保持しているノード

worker (複数)
    素材をmaterialsノードからダウンロードし、エンコードし、成果物をstorageノードへアップロードするノード
