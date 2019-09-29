#!/usr/bin/env python

"""
AMR to MRP-json converter.

Usage:
./amr2mrp.py -i AMR_FILE -o MRP_FILE

...or use the convert() function from your code
"""

import copy
import json
import re
from argparse import ArgumentParser
from datetime import datetime
import sys


class Sentence(object):
    def __init__(self, sentid='', sent='', raw_amr='', comments='',
                 amr_nodes=None, graph=None):
        if graph is None:
            graph = list()
        if amr_nodes is None:
            amr_nodes = dict()
        self.sentid = sentid  # Sentence id
        self.sent = sent  # Sentence
        self.raw_amr = raw_amr  # Raw AMR
        self.comments = comments  # Comments
        self.amr_nodes = amr_nodes  # AMR nodes table
        self.graph = graph  # Path of the whole graph
        self.amr_paths = dict()  # AMR paths
        self.named_entities = dict()  # Named entities

    def __str__(self):
        return '%s%s\n' % (self.comments, self.raw_amr)


class Node(object):
    def __init__(self, name='', ful_name='', next_nodes=None, edge_label='',
                 is_entity=False, entity_type='', entity_name='', wiki='',
                 polarity=False, content=''):
        if next_nodes is None:
            next_nodes = []
        self.name = name  # Node name (acronym)
        self.ful_name = ful_name  # Full name of the node
        self.next_nodes = next_nodes  # Next nodes (list)
        self.edge_label = edge_label  # Edge label between two nodes
        self.is_entity = is_entity  # Whether the node is named entity
        self.entity_type = entity_type  # Entity type
        self.entity_name = entity_name  # Entity name
        self.wiki = wiki  # Entity Wikipedia title
        self.polarity = polarity  # Whether the node is polarity
        self.content = content  # Original content

    def __str__(self):
        if not self.ful_name:
            name = 'NODE NAME: %s\n' % self.name
        else:
            name = 'NODE NAME: %s / %s\n' % (self.name, self.ful_name)
        polarity = 'POLARITY: %s\n' % self.polarity
        children = 'LINK TO:\n'
        for i in self.next_nodes:
            if not i.ful_name:
                children += '\t(%s) -> %s\n' % (i.edge_label, i.name)
            else:
                children += '\t(%s) -> %s / %s\n' % \
                            (i.edge_label, i.name, i.ful_name)
        if not self.is_entity:
            return name + polarity + children
        else:
            s = 'ENTITY TYPE: %s\nENTITY NAME: %s\nWIKIPEDIA TITLE: %s\n' % \
                (self.entity_type, self.entity_name, self.wiki)
            return name + polarity + s + children


def amr_validator(raw_amr):
    """
    AMR validator
    :param str raw_amr:
    :return bool:
    """
    if raw_amr.count('(') == 0:
        return False
    if raw_amr.count(')') == 0:
        return False
    if raw_amr.count('(') != raw_amr.count(')'):
        return False
    return True


def split_amr(raw_amr, contents):
    """
    Split raw AMR based on '()'
    :param str raw_amr:
    :param list contents:
    """
    if not raw_amr:
        return
    else:
        if raw_amr[0] == '(':
            contents.append([])
            for i in contents:
                i.append(raw_amr[0])
        elif raw_amr[0] == ')':
            for i in contents:
                i.append(raw_amr[0])
            amr_contents.append(''.join(contents[-1]))
            contents.pop(-1)
        else:
            for i in contents:
                i.append(raw_amr[0])
        raw_amr = raw_amr[1:]
        split_amr(raw_amr, contents)


def retrieve_path(node, parent, path):
    """
    Retrieve AMR nodes path
    :param Node_object node:
    :param str parent:
    :param list path:
    """
    path.append((parent, node.name, node.edge_label))
    for i in node.next_nodes:
        retrieve_path(i, node.name, path)


def generate_node_single(content, amr_nodes_content, amr_nodes_acronym):
    """
    Generate Node object for single '()'
    :param str content:
    :param dict amr_nodes_content: content as key
    :param dict amr_nodes_acronym: acronym as key
    """
    try:
        assert content.count('(') == 1 and content.count(')') == 1
    except AssertionError:
        raise Exception('Unmatched parenthesis')

    predict_event = re.search('(\w+)\s/\s(\S+)', content)
    if predict_event:
        acr = predict_event.group(1)  # Acronym
        ful = predict_event.group(2).strip(')')  # Full name
    else:
        acr, ful = '-', '-'

    # In case of :polarity -
    is_polarity = True if re.search(":polarity\s-", content) else False

    # :ARG nodes
    arg_nodes = []
    nodes = re.findall(':\S+\s\S+', content)
    for i in nodes:
        i = re.search('(:\S+)\s(\S+)', i)
        role = i.group(1)
        concept = i.group(2).strip(')')

        # if role == ':wiki' and is_named_entity:
        #     continue
        # if role == ':polarity':
        #     continue

        if concept in amr_nodes_acronym:
            node = copy.copy(amr_nodes_acronym[concept])
            node.next_nodes = []
        # In case of (d / date-entity :year 2012)
        else:
            node = Node(name=concept)
            amr_nodes_acronym[concept] = node
        node.edge_label = role
        arg_nodes.append(node)

    # Node is a named entity
    names = re.findall(':op\d\s\"\S+\"', content)
    if len(names) > 0:
        entity_name = ''
        for i in names:
            entity_name += re.match(':op\d\s\"(\S+)\"', i).group(1) + ' '
        new_node = Node(name=acr, ful_name=ful, next_nodes=arg_nodes,
                        entity_name=entity_name,
                        polarity=is_polarity, content=content)
        amr_nodes_content[content] = new_node
        amr_nodes_acronym[acr] = new_node
    else:
        new_node = Node(name=acr, ful_name=ful, next_nodes=arg_nodes,
                        polarity=is_polarity, content=content)
        amr_nodes_content[content] = new_node
        amr_nodes_acronym[acr] = new_node


def generate_nodes_multiple(content, amr_nodes_content, amr_nodes_acronym):
    """
    Generate Node object for nested '()'
    :param str content:
    :param dict amr_nodes_content: content as key
    :param dict amr_nodes_acronym: acronym as key
    """
    try:
        assert content.count('(') > 1 and content.count(')') > 1
        assert content.count('(') == content.count(')')
    except AssertionError:
        raise Exception('Unmatched parenthesis')

    _content = content
    arg_nodes = []
    is_named_entity = False
    ne = None

    # Remove existing nodes from the content, and link these nodes to the root
    # of the subtree
    for i in sorted(amr_nodes_content, key=len, reverse=True):
        if i in content:
            e = content.find(i)
            s = content[:e].rfind(':')
            role = re.search(':\S+\s', content[s:e]).group()  # Edge label
            content = content.replace(role + i, '', 1)
            amr_nodes_content[i].edge_label = role.strip()
            if ':name' in role:
                is_named_entity = True
                ne = amr_nodes_content[i]
            # else:
            arg_nodes.append(amr_nodes_content[i])

    predict_event = re.search('\w+\s/\s\S+', content).group().split(' / ')
    if predict_event:
        acr = predict_event[0]  # Acronym
        ful = predict_event[1]  # Full name
    else:
        acr, ful = '-', '-'

    # In case of :polarity -
    is_polarity = True if re.search(":polarity\s-", content) else False

    nodes = re.findall(':\S+\s\S+', content)
    for i in nodes:
        i = re.search('(:\S+)\s(\S+)', i)
        role = i.group(1)
        concept = i.group(2).strip(')')

        # if role == ':wiki' and is_named_entity:
        #     continue
        # if role == ':polarity':
        #     continue

        if concept in amr_nodes_acronym:
            node = copy.copy(amr_nodes_acronym[concept])
            node.next_nodes = []
        # In case of (d / date-entity :year 2012)
        else:
            node = Node(name=concept)
            amr_nodes_acronym[concept] = node
        node.edge_label = role
        arg_nodes.append(node)

    if is_named_entity:
        # Get Wikipedia title:
        if re.match('.+:wiki\s-.*', content):
            wikititle = '-'  # Entity is NIL, Wiki title does not exist
        else:
            m = re.search(':wiki\s\"(.+?)\"', content)
            if m:
                wikititle = m.group(1)  # Wiki title
            else:
                wikititle = ''  # There is no Wiki title information

        new_node = Node(name=acr, ful_name=ful, next_nodes=arg_nodes,
                        edge_label=ne.ful_name, is_entity=True,
                        entity_type=ful, entity_name=ne.entity_name,
                        wiki=wikititle, polarity=is_polarity, content=content)
        amr_nodes_content[_content] = new_node
        amr_nodes_acronym[acr] = new_node

    elif len(arg_nodes) > 0:
        new_node = Node(name=acr, ful_name=ful, next_nodes=arg_nodes,
                        polarity=is_polarity, content=content)
        amr_nodes_content[_content] = new_node
        amr_nodes_acronym[acr] = new_node


def revise_node(content, amr_nodes_content, amr_nodes_acronym):
    """
    In case of single '()' contains multiple nodes
    e.x. (m / moment :poss p5)
    :param str content:
    :param dict amr_nodes_content: content as key
    :param dict amr_nodes_acronym: acronym as key
    """
    m = re.search('\w+\s/\s\S+\s+(.+)', content.replace('\n', ''))
    if m and ' / name' not in content and ':polarity -' not in content:
        arg_nodes = []
        acr = re.search('\w+\s/\s\S+', content).group().split(' / ')[0]
        nodes = re.findall('\S+\s\".+\"|\S+\s\S+', m.group(1))
        for i in nodes:
            i = re.search('(:\S+)\s(.+)', i)
            role = i.group(1)
            concept = i.group(2).strip(')')
            if concept in amr_nodes_acronym:
                node = copy.copy(amr_nodes_acronym[concept])
                node.next_nodes = []
            else:  # in case of (d / date-entity :year 2012)
                node = Node(name=concept)
                amr_nodes_acronym[concept] = node
            node.edge_label = role
            arg_nodes.append(node)
        amr_nodes_acronym[acr].next_nodes = arg_nodes
        amr_nodes_content[content].next_nodes = arg_nodes


def amr_reader(raw_amr):
    """
    :param str raw_amr: input raw amr
    :return dict amr_nodes_acronym:
    :return list path:
    """
    global amr_contents
    amr_contents = []
    amr_nodes_content = {}  # Content as key
    amr_nodes_acronym = {}  # Acronym as key
    path = []  # Nodes path

    split_amr(raw_amr, [])
    for i in amr_contents:
        if i.count('(') == 1 and i.count(')') == 1:
            generate_node_single(i, amr_nodes_content, amr_nodes_acronym)
    for i in amr_contents:
        if i.count('(') > 1 and i.count(')') > 1:
            generate_nodes_multiple(i, amr_nodes_content, amr_nodes_acronym)
    # for i in amr_contents:
    #     if i.count('(') == 1 and i.count(')') == 1:
    #         revise_node(i, amr_nodes_content, amr_nodes_acronym)

    # The longest node (entire AMR) should be the root
    root = amr_nodes_content[sorted(amr_nodes_content, key=len, reverse=True)[0]]
    retrieve_path(root, '@', path)

    return amr_nodes_acronym, path


def parse(raw_amrs):
    """
    :param str raw_amrs: input raw amrs, separated by '\n'
    :return list res: Sentence objects
    """
    res = []
    for i in re.split('\n\s*\n', raw_amrs):
        sent = re.search('::snt (.*?)\n', i)
        sent = sent.group(1) if sent else ''
        sentid = re.search('::id (.*?)\n', i)
        sentid = sentid.group(1)

        raw_amr = ''
        comments = ''
        for amr_line in i.splitlines(True):
            if amr_line.startswith('# '):
                comments += amr_line
                continue

            raw_amr += amr_line

        if not raw_amr:
            continue
        if not amr_validator(raw_amr):
            raise Exception('Invalid raw AMR: %s' % sentid)

        amr_nodes_acronym, path = amr_reader(raw_amr)
        sent_obj = Sentence(sentid, sent, raw_amr, comments,
                            amr_nodes_acronym, path)
        res.append(sent_obj)

    return res


def convert(amr_sentence):
    """
    :param str amr_sentence: one AMR sentence (plain text)
    """

    out = parse(amr_sentence)[0]
    mrp = {"flavor": 2, "framework": "amr", "version": 0.9, "tops": [0], 'id': out.sentid}
    now = datetime.now()
    time = now.strftime("%d/%m/%Y %H:%M:%S")
    mrp["time"] = time
    mrp['input'] = out.sent

    nodes = []

    for node in out.amr_nodes:
        r_node = out.amr_nodes[node]
        if r_node.ful_name:
            node_entry = {"id": node, "label": r_node.ful_name}
            if len(r_node.next_nodes) > 0:
                node_entry['properties'] = []
                node_entry['values'] = []
                for n in r_node.next_nodes:
                    if n.ful_name:
                        continue
                    node_entry['values'].append(n.name.strip('"'))
                    node_entry['properties'].append(n.edge_label[1:])
                if len(node_entry['properties']) == 0:
                    node_entry.pop('properties')
                if len(node_entry['values']) == 0:
                    node_entry.pop('values')
            nodes.append(node_entry)
    mrp['nodes'] = nodes

    edges = []
    for el in out.graph:
        (source, target, label) = el
        if label:
            if out.amr_nodes[target].ful_name:
                edge = {"source": source, "target": target, "label": label[1:]}
                edges.append(edge)
    mrp['edges'] = edges
    return mrp


if __name__ == '__main__':
    parser = ArgumentParser(description='AMR to MRP converter')
    parser.add_argument('-i', '--input_file', type=str, help='input AMR file', required=True)
    parser.add_argument('-o', '--output_file', type=str, help='output MRP file')
    args = parser.parse_args()

    amr_phrases = []
    cur_phrase = ''
    for line in open(args.input_file):
        if line.strip():
            cur_phrase += line
        else:
            amr_phrases.append(cur_phrase)
            cur_phrase = ''

    if args.output_file:
        outfile = open(args.output_file, 'a')
    else:
        outfile = None

    converted_sentences = []
    
    sys.setrecursionlimit(10000)  # It sets recursion limit to 10000.

    for sentence in amr_phrases:
        try:
            converted = convert(sentence)
        except RecursionError:
            print('Recursion error!', file=sys.stderr)
            continue
        print('Converted:', converted['id'], file=sys.stderr)
        converted_sentences.append(converted)

    for converted in converted_sentences:
        if outfile:
            outfile.write(json.dumps(converted) + '\n')
        else:
            converted_nice = json.dumps(converted, ensure_ascii=False, sort_keys=True, indent=4)
            print(converted_nice)

    if outfile:
        outfile.close()
