
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