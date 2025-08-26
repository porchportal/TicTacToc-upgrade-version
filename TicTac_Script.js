// alert("Box Click to Start Game");

let boxes = document.querySelectorAll(".box");
let resetBtn = document.querySelector("#reset-btn");
let newGameBtn = document.querySelector("#new-btn");
let msgContainer = document.querySelector(".msg-container");
let msg = document.querySelector("#msg");
let mode = document.querySelector(".mode");
let body1 = document.querySelector(".body1");
let mdp = document.querySelector(".mdp");
let md = document.querySelector(".md");
// let line1 = document.querySelector(".line1");
// let line2 = document.querySelector(".line2");
// let line3 = document.querySelector(".line3");
// let line4 = document.querySelector(".line4");
// let line5 = document.querySelector(".line5");
// let line6 = document.querySelector(".line6");
// let line7 = document.querySelector(".line7");
// let line8 = document.querySelector(".line8");

// console.dir(window);

// console.dir(boxes);

let bcmode = true;

const chamode = () => {
    if (bcmode) {
        body1.style.backgroundColor = "#242e2f";
        mode.classList.add("modem");
        mode.classList.remove("modem2");
        for (let box0 of boxes) {
            box0.classList.add("bosh");
        };
        mdp.innerText = "Light";
        mdp.style.marginLeft = "6px";
        bcmode = false;
    }else{
        body1.style.backgroundColor = "#00897B";
        mode.classList.remove("modem");
        mode.classList.add("modem2");
        for (let box0 of boxes) {
            box0.classList.remove("bosh");
        };
        mdp.innerText = "Dark";
        mdp.style.marginLeft = "24px";
        bcmode = true;
    };
};

mode.addEventListener("click", chamode);
mdp.addEventListener("click", chamode);

let drawGame = 8;
let count = 0;

let draw = () => {
    if (count === drawGame) {
        console.log("its work");
        showDrow();
    } else{
        count++;
    };
};

let turnO = true;
const winPatterns = [
    [0, 1, 2],
    [3, 4, 5],
    [6, 7, 8],
    [0, 3, 6],
    [1, 4, 7],
    [2, 5, 8],
    [0, 4, 8],
    [2, 4, 6]
];

// var see = [0, 1, 2];
// var see2 = [0, 1, 2];
// let fline1 = true;
// let fline2 = false;
// let fline3 = false;


// const setline = () => {
//     for (let x of winPatterns) {
//         console.log(see === see2);
//         if (x === 0) {
//             fline1 = true;
//             console.log("1st true");
//         } else{
//             fline1 = false;
//         }
//         console.log(x);
//         if (x === 3) {
//             fline2 = true;
//             console.log("2nd true");
//         } else {
//             fline2 = false;
//         }
//         console.log(x);
//         if (x === 6) {
//             fline3 = true;
//             console.log("3rd true");
//         } else {
//             fline3 = false;
//         }
//         console.log(x);
//         if (fline1 === fline2 && fline2 === fline3) {
//             line6.classList.remove("hideline");
//         } else {
//             line6.classList.add("hideline");
//         }
//     }
//     // if (patt[0] === 3) {
//     //     console.log("YES '3'");
//     // }
//     // if (patt[0] === 6) {
//     //     console.log("YES '6'");
//     // }
//     console.log("NO");
// };

const resetGame = () => {
    turnO = true;
    enableBoxes();
    msgContainer.classList.add("hide");
    count = 0;
};

boxes.forEach((box) => {
    box.addEventListener("click", () => {
        if (turnO) {
            box.classList.add("clr");
            box.innerText = "X";
            turnO = false;
        } else {
            box.classList.remove("clr");
            box.innerText = "O";
            turnO = true;
        };
        box.disabled = true;

        checkWinner();
        draw();
        // setline();
    });
});

const disableBoxes = () => {
    for(let box of boxes) {
        box.disabled = true;
    };
};

const enableBoxes = () => {
    for (let box of boxes) {
        box.disabled = false;
        box.innerText = "";
    };
};

const showWinner = (winner) => {
    msg.innerText = `Congratulations, Winner is ${" "}' ${winner} '`;
    msgContainer.classList.remove("hide");
    disableBoxes();
};

const showDrow = () => {
    msg.innerText = `Game Drow`;
    msgContainer.classList.remove("hide");
};

const checkWinner = () => {
    for(let pattern of winPatterns) {
        var pos1Val = boxes[pattern[0]].innerText;
        var pos2Val = boxes[pattern[1]].innerText;
        var pos3Val = boxes[pattern[2]].innerText;

        if (pos1Val != "" && pos2Val != "" && pos3Val != "") {
            if (pos1Val === pos2Val && pos2Val === pos3Val) {
                showWinner(pos1Val);
                // line1.classList.remove("hideline");
            };
        };
    };
};

newGameBtn.addEventListener("click", resetGame);
resetBtn.addEventListener("click", resetGame);
