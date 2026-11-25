"""Optional 8x8 digits software demonstration, NOT MNIST or FPGA validation.
Exports quantized weights, integer biases and one sample for later RTL integration.
"""
import argparse
from pathlib import Path
import numpy as np
from sklearn.datasets import load_digits
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import train_test_split


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, default=Path('exports'))
    args = parser.parse_args()
    X, y = load_digits(return_X_y=True)
    # Map unsigned pixel intensities into nonnegative signed-int8 range.
    X_train, X_test, y_train, y_test = train_test_split(
        X / 16.0, y, test_size=0.25, random_state=42, stratify=y)
    model = LogisticRegression(max_iter=1000, random_state=42).fit(X_train, y_train)
    sx = 127.0
    sw = 127.0 / np.max(np.abs(model.coef_))
    W = np.clip(np.rint(model.coef_ * sw), -127, 127).astype(np.int8)
    Q = np.clip(np.rint(X_test * sx), 0, 127).astype(np.int8)
    bias = np.rint(model.intercept_ * sx * sw).astype(np.int64)
    # Wide software arithmetic models exact signed dot products. Bias is host-side.
    scores = Q.astype(np.int64) @ W.astype(np.int64).T + bias
    assert np.max(np.abs(scores)) < 2**31
    preds = scores.argmax(axis=1)
    print(f'Floating-point test accuracy: {model.score(X_test,y_test):.4f}')
    print(f'Quantized software test accuracy: {(preds==y_test).mean():.4f}')
    print(f'Test samples: {len(y_test)}; features: {Q.shape[1]}')
    args.out.mkdir(parents=True, exist_ok=True)
    np.savez(args.out/'digits_int8.npz', weights=W, bias=bias,
             sample=Q[0], expected_scores=scores[0], label=y_test[0],
             input_scale=sx, weight_scale=sw)
    def write_hex(name, values, bits):
        mask=(1<<bits)-1
        width=(bits+3)//4
        (args.out/name).write_text(''.join(f'{int(v)&mask:0{width}x}\n' for v in np.ravel(values)))
    write_hex('weights.hex', W, 8)
    write_hex('sample.hex', Q[0], 8)
    write_hex('bias.hex', bias, 32)
    write_hex('expected_dot_products.hex', scores[0]-bias, 32)
    write_hex('expected_scores.hex', scores[0], 32)
    print('Exported class-major weights and reference vectors to', args.out)

if __name__=='__main__':
    main()
