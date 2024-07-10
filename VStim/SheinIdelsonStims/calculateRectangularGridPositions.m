%divide the screen to rectangles and calculate their coordinates
function [obj]=calculateRectangularGridPositions(obj)
%calculate the coordinates for the rectangles that fit into the visual space
centerX=obj.actualVFieldDiameter/2;
centerY=obj.actualVFieldDiameter/2;
w=obj.visualFieldRect(1,3)-obj.visualFieldRect(1,1);
h=obj.visualFieldRect(1,4)-obj.visualFieldRect(1,2);
%calculate the coordinates for the rectangles that fit into the visual space
for i=1:numel(obj.tilingRatio)
    if numel(obj.rectGridSize)==1
        fprintf('Building rectangular grid of %d squares',obj.rectGridSize)
        rectSpacing=floor(h/obj.rectGridSize(1))-1;
        obj.rectSide(i,:)=[rectSpacing*obj.tilingRatio(i),rectSpacing*obj.tilingRatio(i)];
        edgesY=floor((rectSpacing-obj.rectSide(i,2))/2):rectSpacing:(h-obj.rectSide(i,2));
        edgesY=floor(edgesY+((h-(edgesY(end)+obj.rectSide(i,1)))-edgesY(1))/2);
        edgesX=edgesY;
    elseif numel(obj.rectGridSize)==2
        if numel(obj.tilingRatio)>1
            error('Using grids with two sides - rectangles and not square do not work with multiple tiling ratios. Code should be written to make this work!!!')
        end
        fprintf('Building rectangular grid of %d x %d\n',obj.rectGridSize(1),obj.rectGridSize(2));
        rectSpacing(2)=floor(h/obj.rectGridSize(2))-1;
        %if obj.rectangleAspectRatioOne
        %    rectSpacing(1)=rectSpacing(2);
        %else
            rectSpacing(1)=floor(w/obj.rectGridSize(1))-1;
        %end
        obj.rectSide=rectSpacing*obj.tilingRatio;
        edgesY=floor((rectSpacing(2)-obj.rectSide(2))/2):rectSpacing(2):(h-obj.rectSide(2));
        edgesY=floor(edgesY+((h-(edgesY(end)+obj.rectSide(2)))-edgesY(1))/2);
        edgesX=floor((rectSpacing(1)-obj.rectSide(1))/2):rectSpacing(1):(w-obj.rectSide(1));
        edgesX=floor(edgesX+((w-(edgesX(end)+obj.rectSide(1)))-edgesX(1))/2);
        if numel(edgesX)~=obj.rectGridSize(1)
            fprintf('Could not fix the requested number of rectangles with the aspect ratio constraints\nReducing number of X rects to %d\n',numel(edgesX));
            obj.rectGridSize(1)=numel(edgesX);
        end
        %obj.visualFieldRect=[edgesX(1),edgesY(1),edgesX(end)+obj.rectSide(1),edgesY(end)+obj.rectSide(2)];
    else
        error('rectGridSize can only have between 1-2 elements!')
    end

    if (edgesX(1)==0)
        edgesX=edgesX+1;
    end
    if (edgesY(1)==0)
        edgesY=edgesY+1;
    end

    [X1,Y1]=meshgrid(edgesX,edgesY);
    %figure;rectangle('Position',obj.rect,'edgecolor','r');hold on;plot(X1(:),Y1(:),'.');axis equal;
    X1=X1;
    Y1=Y1;
    X2=X1+obj.rectSide(i,1)-1;
    Y2=Y1;
    X3=X1+obj.rectSide(i,1)-1;
    Y3=Y1+obj.rectSide(i,2)-1;
    X4=X1;
    Y4=Y1+obj.rectSide(i,2)-1;

    %move data to object
    obj.rectData.X1{i}=round(X1);obj.rectData.Y1{i}=round(Y1);
    obj.rectData.X2{i}=round(X2);obj.rectData.Y2{i}=round(Y2);
    obj.rectData.X3{i}=round(X3);obj.rectData.Y3{i}=round(Y3);
    obj.rectData.X4{i}=round(X4);obj.rectData.Y4{i}=round(Y4);
    if obj.tilingRatio(i)==max(obj.tilingRatio)
        if ~obj.showOnFullScreen
            obj.pValidRect{i}=find( sqrt((X1-centerX).^2+(Y1-centerY).^2)<=(obj.actualVFieldDiameter/2) &...
                sqrt((X2-centerX).^2+(Y2-centerY).^2)<=(obj.actualVFieldDiameter/2) &...
                sqrt((X3-centerX).^2+(Y3-centerY).^2)<=(obj.actualVFieldDiameter/2) &...
                sqrt((X4-centerX).^2+(Y4-centerY).^2)<=(obj.actualVFieldDiameter/2));
        else
            obj.pValidRect=(1:numel(X1))';
        end
    end

end


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