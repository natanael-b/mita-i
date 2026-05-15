
function timeline(data) {
    const section = document.createElement("section");
    section.appendChild(document.createElement("div")).className = "absolute left-[19px] top-2 bottom-2 w-px bg-neutral-100";

    const container = section.appendChild(document.createElement("div"));
    container.className = "space-y-0";

    for (const event of data) {
        const eventBox = container.appendChild(document.createElement("div"));
        eventBox.className = "relative flex gap-5 pb-8";

        const markerBox = eventBox.appendChild(document.createElement("div"));
        markerBox.className = "shrink-0 flex flex-col items-center";

        const marker = markerBox.appendChild(document.createElement("div"));

        const markerIcon = marker.appendChild(document.createElement("span"));

        // Event itself
        const eventArea = eventBox.appendChild(document.createElement("div"));
        eventArea.className = "pt-1.5 space-y-1 min-w-0";

        const reference = eventArea.appendChild(document.createElement("p"));
        reference.className = "text-[10px] uppercase tracking-widest text-neutral-400 font-medium";
        reference.textContent = event.reference ?? "";

        const title = eventArea.appendChild(document.createElement("p"));
        title.className = "text-sm font-semibold text-neutral-800";
        title.textContent = event.title ?? "";

        const description = eventArea.appendChild(document.createElement("p"));
        description.className = "text-sm text-neutral-500 leading-relaxed";
        description.textContent = event.description ?? "";

        if (event.picture) {
            const image = eventArea.appendChild(document.createElement("img"));
            image.onerror = () => {
                image.onerror = null;
                image.src = "https://placehold.co/700x300/DDDDDD/999999?text=Error+404"
            }
            image.src = event.picture;
        }

        if (data.at(0) !== event && data.at(-1) !== event) {
            markerIcon.textContent = "◆";
            markerIcon.className = "text-neutral-500 text-xs";
            marker.className = "w-10 h-10 rounded-full bg-white border-2 border-neutral-200 flex items-center justify-center shrink-0 z-10";
            continue;
        }

        markerIcon.className = "text-white text-xs";
        marker.className = "w-10 h-10 rounded-full bg-neutral-800 border-4 border-white shadow-sm flex items-center justify-center shrink-0 z-10";

        markerIcon.textContent = data.at(0) === event ? "★" : "●";
    }

    return section;
}

function numbersbox(data) {
    const section = document.createElement("section");
    section.className = "grid grid-cols-2 md:grid-cols-3 gap-3 relative";

    for (const counter of data) {
        const display = section.appendChild(document.createElement("div"));
        display.className = "contador-item cursor-default rounded-2xl p-5 text-center space-y-1";

        const icon = display.appendChild(document.createElement("p"));
        icon.className = "text-2xl";
        icon.appendChild(counter.icon instanceof Node ? counter.icon : document.createTextNode(counter.icon));

        const value = display.appendChild(document.createElement("p"));
        value.className = "text-3xl font-semibold text-neutral-800 leading-none";
        value.textContent = counter.value;
        value.setAttribute("data-target",counter.value);

        const suffix = display.appendChild(document.createElement("p"));
        suffix.className = "text-sm font-medium text-neutral-500";
        suffix.textContent = counter.suffix;

        const label = display.appendChild(document.createElement("p"));
        label.className = "text-xs text-neutral-400 leading-snug";
        label.textContent = counter.label;
    }

    return section;
}

function cardbook(data) {
    const section = document.createElement("section");
    section.className = "grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-3 md:gap-4 cursor-pointer";

    for (const card of data) {
        const display = section.appendChild(document.createElement("article"));
        display.className = "card bg-white rounded-xl overflow-hidden";

        const pictureWrapper = display.appendChild(document.createElement("div"));
        pictureWrapper.className = "w-full aspect-square overflow-hidden bg-[#F0F0F0]";

        const picture = pictureWrapper.appendChild(document.createElement("img"));
        picture.className = "w-full h-full object-cover";
        picture.src = card.picture;


        const textWrapper = display.appendChild(document.createElement("p"));
        textWrapper.className = "p-3 space-y-1";

        const title = textWrapper.appendChild(document.createElement("p"));
        title.className = "text-sm font-semibold text-neutral-800 leading-snug";
        title.textContent = card.title;

        const description = textWrapper.appendChild(document.createElement("p"));
        description.className = "text-xs text-neutral-500 leading-relaxed";
        description.textContent = card.description;

        if (typeof card.onclick === "function") {
            display.setAttribute("onclick",`(${card.onclick.toString()})();`)
        }
    }

    return section;
}

function cardlist(data) {
    const section = document.createElement("section");
    section.className = "space-y-3";

    for (const card of data) {
        const display = section.appendChild(document.createElement("article"));
        display.className = "card cursor-pointer bg-white rounded-xl overflow-hidden flex items-stretch";

        const pictureWrapper = display.appendChild(document.createElement("div"));
        pictureWrapper.className = "w-24 md:w-32 shrink-0 overflow-hidden bg-[#F0F0F0]";

        const picture = pictureWrapper.appendChild(document.createElement("img"));
        picture.className = "w-full h-full object-cover";
        picture.src = card.picture;

        const textWrapper = display.appendChild(document.createElement("p"));
        textWrapper.className = "p-4 flex flex-col justify-center space-y-1 min-w-0";

        const title = textWrapper.appendChild(document.createElement("p"));
        title.className = "text-sm font-semibold text-neutral-800 leading-snug";
        title.textContent = card.title;

        const description = textWrapper.appendChild(document.createElement("p"));
        description.className = "text-xs text-neutral-500 leading-relaxed line-clamp-2";
        description.textContent = card.description;

        if (typeof card.onclick === "function") {
            display.setAttribute("onclick",`(${card.onclick.toString()})();`)
        }
    }

    return section;
}

function gallery(data) {
    const section = document.createElement("section");
    section.className = "grid grid-cols-2 gap-2";

    for (const picture of data) {
        const pictureWrapper = section.appendChild(document.createElement("div"));
        pictureWrapper.className = "foto-item cursor-pointer rounded-xl bg-[#F0F0F0] overflow-hidden";
        pictureWrapper.className += (picture.square ? " aspect-square" : " col-span-2 aspect-video");

        const photo = pictureWrapper.appendChild(document.createElement("img"));
        photo.className = "w-full h-full object-cover";
        photo.src = picture.url;

        if (typeof picture.onclick === "function") {
            pictureWrapper.setAttribute("onclick",`(${picture.onclick.toString()})();`)
        }
    }

    return section;
}

function iconbox(data) {
    const section = document.createElement("section");
    section.className = "grid grid-cols-4 gap-2";

    for (const counter of data) {
        const display = section.appendChild(document.createElement("div"));
        display.className = "acao-item cursor-pointer flex flex-col items-center gap-1.5 rounded-xl p-3 text-center";

        const icon = display.appendChild(document.createElement("p"));
        icon.className = "text-2xl";
        icon.appendChild(counter.icon instanceof Node ? counter.icon : document.createTextNode(counter.icon));

        const label = display.appendChild(document.createElement("p"));
        label.className = "text-[11px] font-medium text-neutral-600 leading-tight";
        label.textContent = counter.label;

        if (typeof counter.onclick === "function") {
            display.setAttribute("onclick",`(${counter.onclick.toString()})();`)
        }
    }

    return section;
}


function listbox(data) {
    const section = document.createElement("section");
    section.className = "space-y-2";

    for (const counter of data) {
        const display = section.appendChild(document.createElement("div"));
        display.className = "acao-item cursor-pointer flex items-center gap-4 rounded-xl px-4 py-3.5";

        const icon = display.appendChild(document.createElement("p"));
        icon.className = "text-xl shrink-0";
        icon.appendChild(counter.icon instanceof Node ? counter.icon : document.createTextNode(counter.icon));

        const textWrapper = display.appendChild(document.createElement("p"));
        textWrapper.className = "flex-1 min-w-0";

        const title = textWrapper.appendChild(document.createElement("p"));
        title.className = "text-sm font-semibold text-neutral-800";
        title.textContent = counter.label;

        const description = textWrapper.appendChild(document.createElement("p"));
        description.className = "text-xs text-neutral-400 truncate";
        description.textContent = counter.description;

        if (counter.highlight) {
            title.className = "text-[10px] uppercase text-neutral-400 font-medium";
            description.className = "text-sm font-medium truncate";
        }

        if (typeof counter.onclick === "function") {
            display.setAttribute("onclick",`(${counter.onclick.toString()})();`)
        }

        if (counter.arrow === false) {
            continue;
        }

        const arrowBox = display.appendChild(document.createElement("svg"));
        arrowBox.className = "w-4 h-4 text-neutral-300 shrink-0";
        arrowBox.setAttribute("viewBox","0 0 20 20");
        arrowBox.setAttribute("fill","currentColor");

        const arrowIcon = arrowBox.appendChild(document.createElement("path"));
        arrowIcon.setAttribute("clip-rule","evenodd");
        arrowIcon.setAttribute("fill-rule","evenodd");
        arrowIcon.setAttribute("d","M7.21 14.77a.75.75 0 01.02-1.06L11.168 10 7.23 6.29a.75.75 0 111.04-1.08l4.5 4.25a.75.75 0 010 1.08l-4.5 4.25a.75.75 0 01-1.06-.02z");
    }

    return section;
}


function pillbox(data) {
    const section = document.createElement("section");
    section.className = "flex flex-wrap gap-2";

    for (const counter of data) {
        const display = section.appendChild(document.createElement("a"));
        display.className = "social-pill flex items-center gap-2 rounded-full px-4 py-2 text-sm text-neutral-700";

        const icon = display.appendChild(document.createElement("p"));
        icon.className = "w-5 h-5 shrink-0 text-center";
        icon.appendChild(counter.icon instanceof Node ? counter.icon : document.createTextNode(counter.icon));

        const text = display.appendChild(document.createElement("p"));
        text.className = "text-sm font-semibold text-neutral-800";
        text.textContent = counter.text;

        if (typeof counter.onclick === "function") {
            display.setAttribute("onclick",`(${counter.onclick.toString()})();`)
        }

        if (counter.icon instanceof Node) {
            continue;
        }
    }

    return section;
}

function keyvalue(data) {
    const STATUS = {
        passed: "bg-green-100 text-green-700 p-1.5",
        dimmed: "bg-neutral-100 text-neutral-400 p-1.5",
        normal: "bg-neutral-100 text-neutral-700 p-1.5",
        warning: "bg-yellow-100 text-yellow-700 p-1.5",
        error: "bg-red-100 text-red-700 p-1.5",
        dimmed: "bg-neutral-100 text-neutral-400 p-1.5",
       "normal-base": "text-neutral-700",
       "dimmed-base": "text-neutral-700",
    };

    const section = document.createElement("section");
    section.className = "space-y-1";

    for (const counter of data) {
        const row = section.appendChild(document.createElement("div"));
        row.className = "flex justify-between items-center rounded-xl px-3 py-2";
        
        const key = row.appendChild(document.createElement("span"));
        key.className = "text-sm text-neutral-600";
        key.textContent = counter.key;
        
        const value = row.appendChild(document.createElement("span"));
        value.className = `text-sm font-medium ${STATUS[counter.status] ? STATUS[counter.status] : STATUS.normal}`;
        value.textContent = counter.value;
    }

    return section;
}

function stats(data) {
    const section = document.createElement("section");
    section.className = "border border-[#EBEBEB] rounded-xl overflow-hidden flex divide-x divide-[#F0F0F0]";

    for (const counter of data) {
        const display = section.appendChild(document.createElement("div"));
        display.className = "flex-1 text-center py-3 px-2";

        const title = display.appendChild(document.createElement("p"));
        title.className = "text-lg font-semibold text-neutral-800";
        title.textContent = counter.header;

        const description = display.appendChild(document.createElement("p"));
        description.className = "text-xs text-neutral-400 mt-0.5";
        description.textContent = counter.label;

        if (typeof counter.onclick === "function") {
            display.setAttribute("onclick",`(${counter.onclick.toString()})();`)
        }
    }

    return section;
}

function content(data) {
    const section = document.createElement("section");
    section.className = "space-y-6";

    const index = section.appendChild(document.createElement("nav"));
    index.className = "space-y-0.5";

    for (const [j,block] of Object.entries(data)) {
        const i = parseInt(j)+1;
        const indexItem = index.appendChild(document.createElement("a"));
        indexItem.className = "indice-item flex items-center gap-3 rounded-xl px-3 py-2.5 cursor-pointer text-neutral-700 no-underline";
        indexItem.href = `#${i}-section`;
        
        const indexItemCount = indexItem.appendChild(document.createElement("span"));
        indexItemCount.className = "text-xs font-medium text-neutral-300 w-5 shrink-0";
        indexItemCount.textContent = i;

        const indexItemText = indexItem.appendChild(document.createElement("span"));
        indexItemText.className = "text-sm";
        indexItemText.textContent = block.title;

        section.appendChild(document.createElement("hr")).className = "border-neutral-100";

        const article = section.appendChild(document.createElement("article"));
        article.className = "py-6 space-y-4";

        const articleHeader = article.appendChild(document.createElement("div"));
        articleHeader.className = "flex items-start gap-3";

        const articleHeaderCount = articleHeader.appendChild(document.createElement("span"));
        articleHeaderCount.className = "text-xs font-medium text-neutral-300 mt-1 w-5 shrink-0";
        articleHeaderCount.textContent = i;

        const articleTitle = articleHeader.appendChild(document.createElement("h2"));
        articleTitle.className = "text-base font-semibold text-neutral-800 leading-snug";
        articleTitle.textContent = block.title;
        articleTitle.id = `${i}-section`;

        if (block.picture) {
            const pictureWrapper = article.appendChild(document.createElement("div"));
            pictureWrapper.className = "w-full rounded-xl overflow-hidden bg-[#F0F0F0]";

            const picture = pictureWrapper.appendChild(document.createElement("img"));
            picture.onerror = () => {
                picture.onerror = null;
                picture.src = "https://placehold.co/700x300/DDDDDD/999999?text=Error+404"
            }
            picture.src = block.picture;
        }

        const articleContent = article.appendChild(document.createElement("div"));
        articleContent.className = "text-sm text-neutral-600 leading-relaxed space-y-2";
        articleContent.innerHTML = block.content;
    }

    return section;
}

function collapse(data) {
    const section = document.createElement("div");
    section.className = "divide-y divide-neutral-100";

    for (const block of data) {

        const contentWrapper = section.appendChild(document.createElement("div"));
        contentWrapper.className = "faq-item";

        const contentHeader = contentWrapper.appendChild(document.createElement("button"));
        contentHeader.className = "cursor-pointer w-full flex items-center justify-between gap-4 py-4 text-left";

        const contentHeaderText = contentHeader.appendChild(document.createElement("span"));
        contentHeaderText.className = "text-sm font-medium text-neutral-800";
        contentHeaderText.textContent = block.summary;

        const contentHeaderIcon = contentHeader.appendChild(document.createElement("span"));
        contentHeaderIcon.className = "faq-icone shrink-0 text-neutral-400 text-lg leading-none";
        contentHeaderIcon.textContent = "+";

        const articleWrapper = contentWrapper.appendChild(document.createElement("article"));
        articleWrapper.className = "faq-resposta";

        const articleBox = articleWrapper.appendChild(document.createElement("div"));
        const articleContent = articleBox.appendChild(document.createElement("div"));
        articleContent.classList = "pb-4 text-sm text-neutral-500 leading-relaxed";
        articleContent.innerHTML = block.content;

        contentHeader.setAttribute("onclick",`(${((event) => {
            const item = event.target.closest('.faq-item');
            const resposta = item.querySelector('.faq-resposta');
            const aberta = item.classList.contains('aberto');
            event.target.closest('section').querySelectorAll('.faq-item').forEach(i => {
                i.classList.remove('aberto');
                i.querySelector('.faq-resposta').classList.remove('aberta');
            });
            if (!aberta) {
                item.classList.add('aberto');
                resposta.classList.add('aberta');
            }

        }).toString()})(event);`);
    }

    return section;
}

function actionlist(data) {
    const section = document.createElement("section");
    section.className = "space-y-3";

    for (const card of data) {
        const display = section.appendChild(document.createElement("article"));
        display.className = "card rounded-xl p-4 flex items-center gap-4";

        const pictureWrapper = display.appendChild(document.createElement("div"));
        pictureWrapper.className = "w-16 md:w-16 rounded-xl bg-neutral-100 flex items-center justify-center shrink-0";

        const picture = pictureWrapper.appendChild(document.createElement("img"));
        picture.className = "w-full h-full object-cover";
        picture.src = card.icon;

        const textWrapper = display.appendChild(document.createElement("div"));
        textWrapper.className = "flex-1 min-w-0 space-y-0.5";

        const title = textWrapper.appendChild(document.createElement("p"));
        title.className = "text-sm font-semibold text-neutral-800 truncate";
        title.textContent = card.title;

        const description = textWrapper.appendChild(document.createElement("p"));
        description.className = "text-xs text-neutral-500 leading-relaxed line-clamp-2";
        description.textContent = card.description;

        const metadataBox = textWrapper.appendChild(document.createElement("div"));
        metadataBox.className = "flex items-center gap-2 pt-0.5";

        const mimetype = metadataBox.appendChild(document.createElement("span"));
        mimetype.className = "text-[10px] uppercase tracking-widest font-medium text-neutral-400";
        mimetype.textContent = card.mimetype;

        const sepatorMetadata = metadataBox.appendChild(document.createElement("span"));
        sepatorMetadata.className = "text-neutral-200";
        sepatorMetadata.textContent = "·";

        const size = metadataBox.appendChild(document.createElement("span"));
        size.className = "text-[10px] text-neutral-400";
        size.textContent = card.size;

        const actionButton = display.appendChild(document.createElement("button"));
        actionButton.className = `cursor-pointer shrink-0 bg-neutral-800 hover:bg-neutral-700 text-white text-xs 
        font-semibold px-4 py-2 rounded-full transition-colors duration-150`;
        actionButton.textContent = card.button || "Download";


        if (typeof card.url === "function") {
            actionButton.setAttribute("onclick",`(${card.url.toString()})();`);
            continue;
        }

        actionButton.setAttribute("onclick",`((event) => {
            const a = document.body.appendChild(document.createElement("a"));
            a.setAttribute("download","true");
            a.href= \`${encodeURI(card.url)}\`;
            a.click();
            a.remove();
        })(event);`);
    }

    return section;
}

function map(data) {
    const section = document.createElement("section");
    section.className = "space-y-3";

    for (const card of data) {
        const display = section.appendChild(document.createElement("article"));
        display.className = "space-y-6";

        const mapWrapper = display.appendChild(document.createElement("div"));
        mapWrapper.className = "w-full rounded-xl overflow-hidden bg-[#E8E8E8]";

        const mapBox = mapWrapper.appendChild(document.createElement("div"));
        mapBox.className = "relative w-full aspect-video select-none";

        const query = encodeURIComponent(`${card.coordinates}`);
       
        const map = mapBox.appendChild(document.createElement("iframe"));
        map.className = "absolute inset-0 w-full h-full border-0";
        map.setAttribute("loading","lazy");
        map.setAttribute("referrerpolicy","no-referrer-when-downgrade");
        map.src = `https://www.google.com/maps?q=${query}&z=16&hl=pt-BR&output=embed&t=p`;

        const textBox = display.appendChild(document.createElement("span"));
        textBox.className = "border flex items-start gap-3 rounded-xl px-3 py-2.5 text-neutral-700";
   
        const icon = textBox.appendChild(document.createElement("span"));
        icon.className = "text-base mt-0.5";
        icon.innerHTML = `
            <svg class="w-5 h-5 text-neutral-400" viewBox="0 0 20 20" fill="currentColor">
                <path 
                    fill-rule="evenodd"
                    clip-rule="evenodd"
                    d="M10 18s6-4.686 6-10A6 6 0 104 8c0 5.314 6 10 6 10zm0-8.5A2.5 2.5 0 1110 4a2.5 2.5 0 010 5.5z"
                ></path>
            </svg>
        `;

        const textWrapper = textBox.appendChild(document.createElement("div"));

        const address = textWrapper.appendChild(document.createElement("p"));
        address.className = "text-sm font-medium";
        address.textContent = card.address;

        const complement = textWrapper.appendChild(document.createElement("p"));
        complement.className = "text-sm text-neutral-500";
        complement.textContent = card.complement;

        const zip = textWrapper.appendChild(document.createElement("p"));
        zip.className = "text-xs text-neutral-400 mt-0.5";
        zip.textContent = card.zip;
    }

    return section;
}

function form(data) {
    const section = document.createElement("section");
    section.className = "space-y-5";

    for (const form of data) {
        const formHeader = form.header;
        const formElement = section.appendChild(document.createElement("form"));
        formElement.setAttribute("target",formHeader.table);
        formElement.className = "space-y-5";

        for (const field of form.fields) {
            const fieldID = Math.random().toString(36).substring(2, 10);

            const fieldWrapper = formElement.appendChild(document.createElement("div"));
            fieldWrapper.className = "space-y-1.5";

            if (field.type === "checkbox" || field.type === "radio") {
                fieldWrapper.className = "space-y-2";

                const optionsLabel = fieldWrapper.appendChild(document.createElement("p"));
                optionsLabel.className = "block tracking-widest text-neutral-400 font-medium";
                optionsLabel.textContent = field.label;

                const optionsWrapper = fieldWrapper.appendChild(document.createElement("div"));
                optionsWrapper.className = "space-y-1 mt-1";

                for (const [key,value] of Object.entries(field.options)){
                    const fieldID = Math.random().toString(36).substring(2, 10);

                    const label = optionsWrapper.appendChild(document.createElement("label"));
                    label.className = "option-label flex items-center gap-3 rounded-xl px-3 py-2.5 cursor-pointer";
                    label.setAttribute("for",fieldID);

                    const input = label.appendChild(document.createElement("input"));
                    input.className = field.type === "checkbox" ? "custom-check" : "custom-radio";
                    input.type = field.type;
                    input.setAttribute("value", value);
                    input.id = fieldID;
                    input.setAttribute("name",field.name);

                    const span = label.appendChild(document.createElement("span"));
                    span.className = "text-sm text-neutral-700";
                    span.textContent = key;
                }

                continue;
            }

            const label = fieldWrapper.appendChild(document.createElement("label"));
            label.className = "text-[11pt] block tracking-widest text-neutral-400 font-medium";
            label.setAttribute("for",fieldID);
            label.textContent = field.label;

            if (field.type === "select") {
                const selectWrapper = fieldWrapper.appendChild(document.createElement("div"));
                selectWrapper.className = "relative";

                const select = selectWrapper.appendChild(document.createElement("select"));
                select.className = "field-input w-full rounded-xl px-4 py-2.5 text-sm text-neutral-700 bg-white appearance-none cursor-pointer pr-10";
                select.id = fieldID;
                select.setAttribute("name",field.name);

                const defaultOption = select.appendChild(document.createElement("option"));
                defaultOption.setAttribute("disabled", "true");
                defaultOption.setAttribute("selected", "true");
                defaultOption.setAttribute("value", "");
                defaultOption.textContent = field.default; 

                for (const [key,value] of Object.entries(field.options)){
                    const option = select.appendChild(document.createElement("option"));
                    option.setAttribute("value", value);
                    option.textContent = key; 
                }

                const arrow = selectWrapper.appendChild(document.createElement("div"));
                arrow.className = "pointer-events-none absolute inset-y-0 right-3 flex items-center";
                arrow.innerHTML = `
                    <svg class="w-4 h-4 text-neutral-400" viewBox="0 0 20 20" fill="currentColor">
                        <path 
                            fill-rule="evenodd" 
                            d="M5.23 7.21a.75.75 0 011.06.02L10 11.168l3.71-3.938a.75.75 0 111.08 1.04l-4.25 4.5a.75.75 0 01-1.08 0l-4.25-4.5a.75.75 0 01.02-1.06z" 
                            clip-rule="evenodd"
                        ></path>
                    </svg>
                `;

                continue;
            }

            const input = fieldWrapper.appendChild(document.createElement("input"));
            input.id = fieldID;
            input.className = "field-input w-full rounded-xl px-4 py-2.5 text-sm text-neutral-700 bg-white cursor-pointer";
            input.type = field.type;
            input.setAttribute("name",field.name);
        }
    }

    const buttonWrapper = section.appendChild(document.createElement("div"));
    buttonWrapper.className = "flex gap-2";

    const resetButton = section.appendChild(document.createElement("button"));
    resetButton.className = `
        cursor-pointer w-full bg-white hover:bg-neutral-100 text-neutral-900 text-sm font-semibold
        px-6 py-3 rounded-xl border border-neutral-200 transition-colors duration-150 reset-button
    `;

    const submitButton = section.appendChild(document.createElement("button"));
    submitButton.className = `
        cursor-pointer w-full bg-neutral-800 hover:bg-neutral-700 text-white text-sm font-semibold
        px-6 py-3 rounded-xl transition-colors duration-150
    `;


    return section;
}

appendBlock(    form([
    {
        header: {
            table: "users"
        },
        fields: [
            {
                type: "text",
                label: "Nome",
                name: "name"
            },
            {
                type: "select",
                label: "Cargo",
                name: "role",
                default: "Selecione",
                options: {
                    Admin: "admin",
                    User: "user"
                }
            },
            {
                type: "radio",
                label: "Sexo",
                name: "gender",
                options: {
                    Masculino: "M",
                    Feminino: "F"
                }
            }
        ]
    }
]));

