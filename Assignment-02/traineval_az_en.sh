#!/bin/bash

set -euo pipefail

RAW_DATA=data/ted_raw/az_en/
BINARIZED_DATA=data/ted_binarized/az_spm8000/az_en/
MODEL_DIR=checkpoints/ted_az_spm8000/az_en/
COMET_DIR=COMET/comet
mkdir -p $MODEL_DIR

fairseq-train \
	$BINARIZED_DATA \
	--task translation \
	--arch transformer_iwslt_de_en \
	--max-epoch 2 \
    --patience 5 \
    --distributed-world-size 1 \
	--share-all-embeddings \
	--no-epoch-checkpoints \
	--dropout 0.3 \
	--optimizer 'adam' --adam-betas '(0.9, 0.98)' --lr-scheduler 'inverse_sqrt' \
	--warmup-init-lr 1e-7 --warmup-updates 4000 --lr 2e-4  \
	--criterion 'label_smoothed_cross_entropy' --label-smoothing 0.1 \
	--max-tokens 4500 \
	--update-freq 2 \
	--seed 2 \
  	--save-dir $MODEL_DIR \
	--log-interval 20 2>&1 | tee $MODEL_DIR/train.log 

# translate & eval the valid and test set
fairseq-generate $BINARIZED_DATA \
    --gen-subset test \
    --path $MODEL_DIR/checkpoint_best.pt \
    --batch-size 32 \
    --remove-bpe sentencepiece \
    --beam 5  | grep ^H | cut -c 3- | sort -n | cut -f3- > "$MODEL_DIR"/test_b5.pred

echo "evaluating test set"
python score.py "$MODEL_DIR"/test_b5.pred "$RAW_DATA"/test.en \
    --src "$RAW_DATA"/test.az \
    --comet-dir $COMET_DIR \
    | tee "$MODEL_DIR"/test_b5.score

fairseq-generate $BINARIZED_DATA \
    --gen-subset valid \
    --path $MODEL_DIR/checkpoint_best.pt \
    --batch-size 32 \
    --remove-bpe sentencepiece \
    --beam 5 | grep ^H | cut -c 3- | sort -n | cut -f3- > "$MODEL_DIR"/valid_b5.pred

echo "evaluating valid set"
python score.py "$MODEL_DIR"/valid_b5.pred "$RAW_DATA"/dev.en \
    --src "$RAW_DATA"/dev.az \
    --comet-dir $COMET_DIR \
    | tee "$MODEL_DIR"/valid_b5.score