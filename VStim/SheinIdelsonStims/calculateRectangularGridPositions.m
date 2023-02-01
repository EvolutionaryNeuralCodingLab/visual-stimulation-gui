%divide the screen to rectangles and calculate their coordinates
function [obj]=calculateRectangularGridPositions(obj)
%calculate the coordinates for the rectangles that fit into the visual space
centerX=obj.actualVFieldDiameter/2;
centerY=obj.actualVFieldDiameter/2;
w=obj.rect(3)-obj.rect(1);
h=obj.rect(4)-obj.rect(2);
%calculate the coordinates for the rectangles that fit into the visual space
if numel(obj.rectGridSize)==1
    fprintf('Building rectangular grid of %d squares',obj.rectGridSize)
    rectSpacing=floor(h/obj.rectGridSize(1))-1;
    rectSide=[rectSpacing*obj.tilingRatio,rectSpacing*obj.tilingRatio];
    edgesY=floor((rectSpacing-rectSide(2))/2):rectSpacing:(h-rectSide(2));
    edgesY=floor(edgesY+((h-(edgesY(end)+rectSide(1)))-edgesY(1))/2);
    edgesX=edgesY;
elseif numel(obj.rectGridSize)==2
    fprintf('Building rectangular grid of %d x %d\n',obj.rectGridSize(1),obj.rectGridSize(2));
    rectSpacing(2)=floor(h/obj.rectGridSize(2))-1;
    if obj.rectangleAspectRatioOne
        rectSpacing(1)=rectSpacing(2);
    else
        rectSpacing(1)=floor(w/obj.rectGridSize(1))-1;
    end
    rectSide=rectSpacing*obj.tilingRatio;
    edgesY=floor((rectSpacing(2)-rectSide(2))/2):rectSpacing(2):(h-rectSide(2));
    edgesY=floor(edgesY+((h-(edgesY(end)+rectSide(2)))-edgesY(1))/2);
    edgesX=floor((rectSpacing(1)-rectSide(1))/2):rectSpacing(1):(w-rectSide(1));
    edgesX=floor(edgesX+((w-(edgesX(end)+rectSide(1)))-edgesX(1))/2);
    if numel(edgesX)~=obj.rectGridSize(1)
        fprintf('Could not fix the requested number of rectangles with the aspect ratio constraints\nReducing number of X rects to %d\n',numel(edgesX));
        obj.rectGridSize(1)=numel(edgesX);
    end
    %obj.visualFieldRect=[edgesX(1),edgesY(1),edgesX(end)+rectSide(1),edgesY(end)+rectSide(2)];
else
    error('rectGridSize can only have between 1-2 elements!')
end

[X1,Y1]=meshgrid(edgesX,edgesY);
%figure;rectangle('Position',obj.rect,'edgecolor','r');hold on;plot(X1(:),Y1(:),'.');axis equal;
X1=X1;
Y1=Y1;
X2=X1+rectSide(1)-1;
Y2=Y1;
X3=X1+rectSide(1)-1;
Y3=Y1+rectSide(2)-1;
X4=X1;
Y4=Y1+rectSide(2)-1;
if ~obj.showOnFullScreen
    obj.pValidRect=find( sqrt((X1-centerX).^2+(Y1-centerY).^2)<=(obj.actualVFieldDiameter/2) &...
        sqrt((X2-centerX).^2+(Y2-centerY).^2)<=(obj.actualVFieldDiameter/2) &...
        sqrt((X3-centerX).^2+(Y3-centerY).^2)<=(obj.actualVFieldDiameter/2) &...
        sqrt((X4-centerX).^2+(Y4-centerY).^2)<=(obj.actualVFieldDiameter/2));
else
    obj.pValidRect=(1:numel(X1))';
end

%move data to object
obj.rectData.X1=X1;obj.rectData.Y1=Y1;
obj.rectData.X2=X2;obj.rectData.Y2=Y2;
obj.rectData.X3=X3;obj.rectData.Y3=Y3;
obj.rectData.X4=X4;obj.rectData.Y4=Y4;

%calculate X and Y position for the valid places
if numel(obj.rectGridSize)==1
    obj.pos2X=rem(obj.pValidRect,obj.rectGridSize);
    obj.pos2X(obj.pos2X==0)=obj.rectGridSize;
    obj.pos2Y=ceil((obj.pValidRect-0.5)/obj.rectGridSize);
else
    obj.pos2X=rem(obj.pValidRect,obj.rectGridSize(1));
    obj.pos2X(obj.pos2X==0)=obj.rectGridSize(1);
    obj.pos2Y=ceil((obj.pValidRect-0.5)/obj.rectGridSize(1));
end
obj.pos2X=obj.pos2X-min(obj.pos2X)+1;
obj.pos2Y=obj.pos2Y-min(obj.pos2Y)+1;
end