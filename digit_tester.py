
# MIT License
#
# Copyright (c) 2023 Caleb Butler
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to
# deal in the Software without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.

def get_pi(filename):
    with open(filename, 'r') as f:
        for line in f:
            pi = line[0] + line[2:]
    return pi

def compare_with_transcript(filename, pi):
    pi = '        ' + pi
    has_test_failed = False
    with open(filename, 'r') as f:
        for i, line in enumerate(f):
            digits = line
            if int(digits) != int(pi[i * 9:i * 9 + 9]):
                has_test_failed = True
                print(f"Difference at line {i}")
                print(f"    Transcript digits = {digits}")
                print(f"    Real digits = {pi[i * 9: i * 9 + 9]}")
    if has_test_failed:
        print('Test failed.')
    else:
        print('Test passed.')

if __name__ == '__main__':
    pi = get_pi('pi.txt')
    compare_with_transcript('transcript.txt', pi)
