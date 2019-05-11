#!/usr/bin/env python

"""
MRP-json to tikz-dependency converter.

Usage:
  $ ./json_tikz.py -i json_data

"""

import json
from argparse import ArgumentParser


def parse_arguments():
    parser = ArgumentParser(description='MRP json to tikz dependencies converter')
    parser.add_argument('-i', '--input-file', metavar='INPUT_FILE',
                        type=str, action='store',
                        default=None, dest='input_file_name',
                        help='input file name', required=True)
    parser.add_argument('-f', '--framework', metavar='F',
                        type=str, action='store',
                        default=None, dest='framework',
                        choices=['psd', 'dm', 'ucca', 'amr', 'eds'],
                        help='framework', required=True)

    args = parser.parse_args()
    return args

def process(args):
    print('\documentclass{minimal}\n'
          '\\usepackage[a4paper,landscape]{geometry}\n'
          '\\usepackage{tikz-dependency}\n'
          '\centering\n'
          '\\begin{document}')
    with open(args.input_file_name, 'r') as i_file:
        for line in i_file:
            json_line = json.loads(line)
            text = json_line['input']
            nodes = json_line['nodes']
            edges = json_line['edges']
            generate_latex(nodes, edges, text, args.framework)
    print('\end{document}')

def generate_latex(nodes, edges, text, framework):

    print('\\resizebox{\columnwidth}{!}{%\n'
          '\\begin{dependency}[theme = default]\n'
          '\\begin{deptext}[column sep=.7em]')
    id_to_index = process_nodes(nodes, framework, text)
    print('\end{deptext}')
    process_edges(edges, id_to_index)
    print('\end{dependency}%\n}\n')
    print('\n' + text + '\n')

def process_nodes(nodes, framework, text):

    if framework == 'ucca':
        node_labels = []
        for node in nodes:
            if 'anchors' in node:
                node_text = []
                for anchor in node['anchors']:
                    node_text_part = text[anchor['from']:anchor['to']]
                    node_text.append(node_text_part)
                node_text = ' '.join(node_text)
                node_labels.append(node_text)
            else:
                node_labels.append('EMPTY')

    elif framework == 'eds':
        node_labels = []
        node_wordforms = []
        for node in nodes:
            node_labels.append(node['label'].replace('_', '\_'))
            if 'values' in node:
                node_wordforms.extend(node['values'])
            else:
                node_wordforms.append(' ')
    else:
        node_labels = [node['label'].replace('#', '\#') for node in nodes]

    node_labels_for_latex = ' \& '.join(node_labels)
    print(node_labels_for_latex + ' \\\\')

    if framework == 'eds':
        node_wordforms_for_latex = ' \& '.join(node_wordforms)
        print(node_wordforms_for_latex + '\\\\')

    id_to_index = {}
    for i, node in enumerate(nodes):
        id_to_index[node['id']] = str(i + 1)

    return id_to_index

def process_edges(edges, id_to_index):
    for edge in edges:
        edge_for_latex = ('\depedge{' + id_to_index[edge['source']] +
                          '}{' + id_to_index[edge['target']] +
                          '}{' + edge['label'] + '}')
        print(edge_for_latex)

if __name__ == '__main__':
    args = parse_arguments()
    process(args)
