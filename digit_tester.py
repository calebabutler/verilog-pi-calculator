
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

'''
This script compares the digits in the pi.txt file with the ones in the
transcript.txt file. The pi.txt file contains the real one million digits of
pi, found online. The transcript.txt file is the stdout output from running
the pi_calculator simulation in Verilator. The use case goes like this:

    1. Install Verilator. On Ubuntu or Debian:
        sudo apt install verilator

    2. Make build.sh executable if it is not.
        chmod +x build.sh

    3. Run build.sh.
        ./build.sh

    4. Run the following command.
        ./obj_dir/Vpi_calculator > transcript.txt

    5. Use this script to compare digits.
        python3 digit_tester.py
'''

def get_pi(filename):
    '''
    This function reads the given file and returns a string with the digits
    of pi (without . separating 3 from the rest).
    '''
    with open(filename, 'r') as f:
        for line in f:
            pi = line[0] + line[2:]
    return pi

def compare_with_transcript(filename, pi):
    '''
    This function reads the transcript file given and compares it with the
    digits of pi given.
    '''
    # Align pi with transcript file
    pi = '        ' + pi
    has_test_failed = False
    with open(filename, 'r') as f:
        for i, line in enumerate(f):
            # Compare ints to avoid differences in representation (0s instead
            # of spaces most importantly).
            if int(line) != int(pi[i * 9:i * 9 + 9]):
                has_test_failed = True
                print(f"Difference at line {i}")
                print(f"    Transcript digits = {line}")
                print(f"    Real digits = {pi[i * 9: i * 9 + 9]}")
    # Print something even if all digits are the same.
    if has_test_failed:
        print('Test failed.')
    else:
        print('Test passed.')

if __name__ == '__main__':
    pi = get_pi('pi.txt')
    compare_with_transcript('transcript.txt', pi)
