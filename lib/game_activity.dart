import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:stop_watch_timer/stop_watch_timer.dart';

import 'bomb_square.dart';
import 'constants.dart';

class GameActivity extends StatefulWidget {
  const GameActivity({Key? key}) : super(key: key);

  @override
  _GameActivityState createState() => _GameActivityState();
}

class _GameActivityState extends State<GameActivity> {
  // Row and column count of the board
  int rowCount = 10;
  int columnCount = 10;

  bool invertTap = false;
  int lastGameTime = 0;
  int lastGameBombs = 0;

  final _stopWatchTimer = StopWatchTimer();

  // The grid of squares
  late List<List<BoardSquare>> board;

  // "Opened" refers to being clicked already
  late List<bool> openedSquares;

  // A flagged square is a square a user has added a flag on by long pressing
  late List<bool> flaggedSquares;

  // Probability that a square will be a bomb
  int bombProbability = 3;
  int maxProbability = 15;

  int bombCount = 0;
  int squaresLeft = 0;

  @override
  void initState() {
    super.initState();
    _initialiseGame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Constants.background,
      body: Padding(
        padding: const EdgeInsets.all(2.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              color: Constants.background,
              height: 60.0,
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  StreamBuilder<int>(
                    stream: _stopWatchTimer.secondTime,
                    initialData: 0,
                    builder: (context, snap) {
                      String time = _formatTime(snap.data!);
                      return Text("Time passed: $time",
                          style: Constants.textStyle);
                    },
                  ),
                  InkWell(
                    onTap: () {
                      _initialiseGame();
                    },
                    child: const CircleAvatar(
                      child: Icon(
                        Icons.cancel,
                        color: Constants.cancel,
                        size: 40.0,
                      ),
                      backgroundColor: Constants.cancelBorder,
                    ),
                  ),
                  Text("Bombs: $bombCount", style: Constants.textStyle)
                ],
              ),
            ),
            // The grid of squares
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columnCount,
              ),
              itemBuilder: (context, position) {
                // Get row and column number of square
                int rowNumber = (position / columnCount).floor();
                int columnNumber = (position % columnCount);

                Image image;

                if (openedSquares[position] == false) {
                  if (flaggedSquares[position] == true) {
                    image = getImage(ImageType.flagged);
                  } else {
                    image = getImage(ImageType.facingDown);
                  }
                } else {
                  if (board[rowNumber][columnNumber].hasBomb) {
                    image = getImage(ImageType.bomb);
                  } else {
                    image = getImage(
                      getImageTypeFromNumber(
                          board[rowNumber][columnNumber].bombsAround),
                    );
                  }
                }

                return InkWell(
                  onTap: () => _onTap(rowNumber, columnNumber, position),
                  onLongPress: () =>
                      _onLongTap(rowNumber, columnNumber, position),
                  splashColor: Constants.grey,
                  child: Container(
                    color: Constants.grey,
                    child: image,
                  ),
                );
              },
              itemCount: rowCount * columnCount,
            ),
            Container(
              color: Constants.background,
              height: 60.0,
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  InkWell(
                    onTap: () => invertTap = !invertTap,
                    child: const CircleAvatar(
                      child: Icon(
                        Icons.touch_app,
                        color: Constants.grey,
                        size: 40.0,
                      ),
                      backgroundColor: Constants.cancelBorder,
                    ),
                  ),
                  TextButton(
                    onPressed: () => _showStats(),
                    child: const Text("Show stats", style: Constants.textStyle),
                    style: TextButton.styleFrom(
                        primary: Constants.grey,
                        backgroundColor: Constants.cancelBorder),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(int secondsTotal) {
    int min = (secondsTotal / 60).floor();
    int sec = secondsTotal - min * 60;
    return sec < 10 ? "$min:0$sec" : "$min:$sec";
  }

  void _onTap(int rowNumber, int columnNumber, int position) {
    if (invertTap) {
      _flagSquare(rowNumber, columnNumber, position);
    } else {
      _openSquare(rowNumber, columnNumber, position);
    }
  }

  void _onLongTap(int rowNumber, int columnNumber, int position) {
    if (invertTap) {
      _openSquare(rowNumber, columnNumber, position);
    } else {
      _flagSquare(rowNumber, columnNumber, position);
    }
  }

  void _openSquare(int rowNumber, int columnNumber, int position) {
    if (board[rowNumber][columnNumber].hasBomb) {
      _handleGameOver();
    }

    if (board[rowNumber][columnNumber].bombsAround == 0) {
      _handleTap(rowNumber, columnNumber);
    } else {
      setState(() {
        openedSquares[position] = true;
        squaresLeft = squaresLeft - 1;
      });
    }

    if (squaresLeft <= bombCount) {
      _handleWin();
    }
  }

  void _flagSquare(int rowNumber, int columnNumber, int position) {
    if (openedSquares[position] == false) {
      setState(() => flaggedSquares[position] = !flaggedSquares[position]);
    }
  }

  void _showStats() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Statistics", textAlign: TextAlign.center),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Previous game: "),
              Text(_formatTime(lastGameTime)),
              const Text("Bombs: "),
              Text(lastGameBombs.toString()),
            ]
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    print(directory);
    return directory.path;
  }

  // Initialises all lists
  void _initialiseGame() {
    lastGameTime = _stopWatchTimer.rawTime.value ~/ 1000;
    lastGameBombs = bombCount;
    _stopWatchTimer.onExecute.add(StopWatchExecute.reset);
    _stopWatchTimer.onExecute.add(StopWatchExecute.start);
    // Initialise all squares to having no bombs
    board = List.generate(rowCount, (i) {
      return List.generate(columnCount, (j) {
        return BoardSquare();
      });
    });

    // Initialise list to store which squares have been opened
    openedSquares = List.generate(rowCount * columnCount, (i) {
      return false;
    });

    flaggedSquares = List.generate(rowCount * columnCount, (i) {
      return false;
    });

    // Resets bomb count
    bombCount = 0;
    squaresLeft = rowCount * columnCount;

    // Randomly generate bombs
    Random random = Random();
    for (int i = 0; i < rowCount; i++) {
      for (int j = 0; j < columnCount; j++) {
        int randomNumber = random.nextInt(maxProbability);
        if (randomNumber < bombProbability) {
          board[i][j].hasBomb = true;
          bombCount++;
        }
      }
    }

    // Check bombs around and assign numbers
    for (int i = 0; i < rowCount; i++) {
      for (int j = 0; j < columnCount; j++) {
        if (i > 0 && j > 0) {
          if (board[i - 1][j - 1].hasBomb) {
            board[i][j].bombsAround++;
          }
        }

        if (i > 0) {
          if (board[i - 1][j].hasBomb) {
            board[i][j].bombsAround++;
          }
        }

        if (i > 0 && j < columnCount - 1) {
          if (board[i - 1][j + 1].hasBomb) {
            board[i][j].bombsAround++;
          }
        }

        if (j > 0) {
          if (board[i][j - 1].hasBomb) {
            board[i][j].bombsAround++;
          }
        }

        if (j < columnCount - 1) {
          if (board[i][j + 1].hasBomb) {
            board[i][j].bombsAround++;
          }
        }

        if (i < rowCount - 1 && j > 0) {
          if (board[i + 1][j - 1].hasBomb) {
            board[i][j].bombsAround++;
          }
        }

        if (i < rowCount - 1) {
          if (board[i + 1][j].hasBomb) {
            board[i][j].bombsAround++;
          }
        }

        if (i < rowCount - 1 && j < columnCount - 1) {
          if (board[i + 1][j + 1].hasBomb) {
            board[i][j].bombsAround++;
          }
        }
      }
    }

    setState(() {});
  }

  // This function opens other squares around the target square which don't have any bombs around them.
  // We use a recursive function which stops at squares which have a non zero number of bombs around them.
  void _handleTap(int i, int j) {
    int position = (i * columnCount) + j;
    openedSquares[position] = true;
    squaresLeft = squaresLeft - 1;

    if (i > 0) {
      if (!board[i - 1][j].hasBomb &&
          openedSquares[((i - 1) * columnCount) + j] != true) {
        if (board[i][j].bombsAround == 0) {
          _handleTap(i - 1, j);
        }
      }
    }

    if (j > 0) {
      if (!board[i][j - 1].hasBomb &&
          openedSquares[(i * columnCount) + j - 1] != true) {
        if (board[i][j].bombsAround == 0) {
          _handleTap(i, j - 1);
        }
      }
    }

    if (j < columnCount - 1) {
      if (!board[i][j + 1].hasBomb &&
          openedSquares[(i * columnCount) + j + 1] != true) {
        if (board[i][j].bombsAround == 0) {
          _handleTap(i, j + 1);
        }
      }
    }

    if (i < rowCount - 1) {
      if (!board[i + 1][j].hasBomb &&
          openedSquares[((i + 1) * columnCount) + j] != true) {
        if (board[i][j].bombsAround == 0) {
          _handleTap(i + 1, j);
        }
      }
    }

    setState(() {});
  }

  // Function to handle when a bomb is clicked.
  void _handleGameOver() {
    _stopWatchTimer.onExecute.add(StopWatchExecute.stop);
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Game Over!"),
          content: const Text("You stepped on a mine!"),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                _initialiseGame();
                Navigator.pop(context);
              },
              child: const Text("Play again"),
            ),
          ],
        );
      },
    );
  }

  void _handleWin() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Congratulations!"),
          content: const Text("You Win!"),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                _initialiseGame();
                Navigator.pop(context);
              },
              child: const Text("Play again"),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() async {
    super.dispose();
    await _stopWatchTimer.dispose(); // Need to call dispose function.
  }

  Image getImage(ImageType type) {
    switch (type) {
      case ImageType.zero:
        return Image.asset('images/0.png');
      case ImageType.one:
        return Image.asset('images/1.png');
      case ImageType.two:
        return Image.asset('images/2.png');
      case ImageType.three:
        return Image.asset('images/3.png');
      case ImageType.four:
        return Image.asset('images/4.png');
      case ImageType.five:
        return Image.asset('images/5.png');
      case ImageType.six:
        return Image.asset('images/6.png');
      case ImageType.seven:
        return Image.asset('images/7.png');
      case ImageType.eight:
        return Image.asset('images/8.png');
      case ImageType.bomb:
        return Image.asset('images/bomb.png');
      case ImageType.facingDown:
        return Image.asset('images/facingDown.png');
      case ImageType.flagged:
        return Image.asset('images/flagged.png');
      default:
        return Image.asset('images/bomb.png');
    }
  }

  ImageType getImageTypeFromNumber(int number) {
    switch (number) {
      case 0:
        return ImageType.zero;
      case 1:
        return ImageType.one;
      case 2:
        return ImageType.two;
      case 3:
        return ImageType.three;
      case 4:
        return ImageType.four;
      case 5:
        return ImageType.five;
      case 6:
        return ImageType.six;
      case 7:
        return ImageType.seven;
      case 8:
        return ImageType.eight;
      default:
        return ImageType.bomb;
    }
  }
}

// Types of images available
enum ImageType {
  zero,
  one,
  two,
  three,
  four,
  five,
  six,
  seven,
  eight,
  bomb,
  facingDown,
  flagged,
}
