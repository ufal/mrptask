#!/usr/bin/env python

"""
MRP-json to tikz-dependency converter.

Usage:
  $ ./json-to-tikz.py -i json_data

"""

import json
from argparse import ArgumentParser


def parse_arguments():
    parser = ArgumentParser(description='MRP json to tikz dependencies converter')
    parser.add_argument('-i', '--input-file', metavar='INPUT_FILE',
                        type=str, action='store',
                        default=None, dest='input_file_name',
                        help='input file name', required=True)

    args = parser.parse_args()
    return args

def process(args):
    print('\documentclass{minimal}\n'
          '\\usepackage[a4paper,landscape]{geometry}\n'
          '\\usepackage{tikz-dependency}\n'
          '\centering\n'
          '\\begin{document}')
    for line in open(args.input_file_name, 'r'):
        json_line = json.loads(line)
        text = json_line['input']
        nodes = json_line['nodes']
        edges = json_line['edges']
        generate_latex(nodes, edges, text)
    print('\end{document}')

def generate_latex(nodes, edges, text):

    print('\\resizebox{\columnwidth}{!}{%\n'
          '\\begin{dependency}[theme = default]\n'
          '\\begin{deptext}[column sep=.7em]')
    id_to_index = process_nodes(nodes)
    print('\end{deptext}')
    process_edges(edges, id_to_index)
    print('\end{dependency}%\n}\n')
    print('\n' + text + '\n')

def process_nodes(nodes):
    node_labels = [node['label'].replace('#', '\#') for node in nodes]
    node_labels_for_latex = ' \& '.join(node_labels)
    id_to_index = {}
    for i, node in enumerate(nodes):
        id_to_index[node['id']] = str(i + 1)
    
    print(node_labels_for_latex + ' \\\\')
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
