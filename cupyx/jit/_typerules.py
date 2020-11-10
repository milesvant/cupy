import ast

import numpy

from cupy._logic import ops
from cupy._math import arithmetic
from cupy._logic import comparison
from cupy._binary import elementwise
from cupy import core

from cupyx.jit import _types


_numpy_scalar_true_divide = core.create_ufunc(
    'numpy_scalar_true_divide',
    ('??->d', '?i->d', 'i?->d', 'bb->f', 'bi->d', 'BB->f', 'Bi->d',
     'hh->f', 'HH->f', 'ii->d', 'II->d', 'll->d', 'LL->d', 'qq->d', 'QQ->d',
     'ee->e', 'ff->f', 'dd->d', 'FF->F', 'DD->D'),
    'out0 = (out0_type)in0 / (out0_type)in1',
)


_numpy_scalar_invert = core.create_ufunc(
    'numpy_scalar_invert',
    ('?->?', 'b->b', 'B->B', 'h->h', 'H->H', 'i->i', 'I->I',
     'l->l', 'L->L', 'q->q', 'Q->Q'),
    'out0 = ~in0',
)


_numpy_scalar_logical_not = core.create_ufunc(
    'numpy_scalar_logical_not',
    ('?->?', 'b->?', 'B->?', 'h->?', 'H->?', 'i->?', 'I->?', 'l->?', 'L->?',
     'q->?', 'Q->?', 'e->?', 'f->?', 'd->?',
     ('F->?', 'out0 = !in0.real() && !in0.imag()'),
     ('D->?', 'out0 = !in0.real() && !in0.imag()')),
    'out0 = !in0',
)


_scalar_lt = core.create_comparison('scalar_less', '<')
_scalar_lte = core.create_comparison('scalar_less', '<=')
_scalar_gt = core.create_comparison('scalar_less', '>')
_scalar_gte = core.create_comparison('scalar_less', '>=')


_numpy_ops = {
    ast.And: ops.logical_and,
    ast.Or: ops.logical_or,
    ast.Add: arithmetic.add,
    ast.Sub: arithmetic.subtract,
    ast.Mult: arithmetic.multiply,
    ast.Pow: arithmetic.power,
    ast.Div: _numpy_scalar_true_divide,
    ast.FloorDiv: arithmetic.floor_divide,
    ast.Mod: arithmetic.remainder,
    ast.LShift: elementwise.left_shift,
    ast.RShift: elementwise.right_shift,
    ast.BitOr: elementwise.bitwise_or,
    ast.BitAnd: elementwise.bitwise_and,
    ast.BitXor: elementwise.bitwise_xor,
    ast.Invert: _numpy_scalar_invert,
    ast.Not: _numpy_scalar_logical_not,
    ast.Eq: comparison.equal,
    ast.NotEq: comparison.not_equal,
    ast.Lt: _scalar_lt,
    ast.LtE: _scalar_lte,
    ast.Gt: _scalar_gt,
    ast.GtE: _scalar_gte,
    ast.USub: arithmetic.negative,
}


def get_ufunc(mode, op_type):
    if mode == 'numpy':
        return _numpy_ops[op_type]
    if mode == 'cuda':
        raise NotImplementedError
    assert False


def get_ctype_from_scalar(mode, x):
    if isinstance(x, numpy.generic):
        return _types.Scalar(x.dtype)

    if mode == 'numpy':
        if isinstance(x, int):
            return _types.Scalar(numpy.int64)
        if isinstance(x, float):
            return _types.Scalar(numpy.float64)
        if isinstance(x, complex):
            return _types.Scalar(numpy.complex128)

    if mode == 'cuda':
        if isinstance(x, int):
            if -(1 << 31) <= x < (1 << 31):
                return _types.Scalar(numpy.int32)
            return _types.Scalar(numpy.int64)
        if isinstance(x, float):
            return _types.Scalar(numpy.float32)
        if isinstance(x, complex):
            return _types.Scalar(numpy.complex64)

    raise NotImplementedError(f'{x} is not supported as a constant.')
